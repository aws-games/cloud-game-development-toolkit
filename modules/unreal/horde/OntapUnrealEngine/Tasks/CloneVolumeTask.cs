// Copyright Epic Games, Inc. All Rights Reserved.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Xml;
using EpicGames.Core;
using Microsoft.Extensions.Logging;
using UnrealBuildBase;

namespace AutomationTool.Tasks
{
	/// <summary>
	/// Parameters for the CloneVolume task
	/// </summary>
	public class CloneVolumeTaskParameters
	{
		/// <summary>
		/// Name of the source volume to clone from.
		/// </summary>
		[TaskParameter]
		public string SourceVolume { get; set; }

		/// <summary>
		/// Name of the snapshot to use for cloning.
		/// </summary>
		[TaskParameter]
		public string SnapshotName { get; set; }

		/// <summary>
		/// Name for the new FlexClone volume.
		/// </summary>
		[TaskParameter]
		public string CloneVolumeName { get; set; }

		/// <summary>
		/// Storage Virtual Machine (SVM) name in ONTAP.
		/// </summary>
		[TaskParameter]
		public string SvmName { get; set; }

		/// <summary>
		/// FSx ONTAP management IP address.
		/// </summary>
		[TaskParameter]
		public string FsxAdminIp { get; set; }

		/// <summary>
		/// ONTAP username (e.g., vsadmin).
		/// </summary>
		[TaskParameter]
		public string OntapUser { get; set; }

		/// <summary>
		/// AWS Secrets Manager secret name containing the FSx password.
		/// </summary>
		[TaskParameter]
		public string AwsSecretName { get; set; }

		/// <summary>
		/// AWS region where the secret is stored.
		/// </summary>
		[TaskParameter]
		public string AwsRegion { get; set; }
	}

	/// <summary>
	/// Creates a FlexClone volume from an existing snapshot.
	/// </summary>
	[TaskElement("CloneVolume", typeof(CloneVolumeTaskParameters))]
	public class CloneVolumeTask : CustomTask
	{
		/// <summary>
		/// Parameters for the task
		/// </summary>
		private readonly CloneVolumeTaskParameters _parameters;

		/// <summary>
		/// Constructor
		/// </summary>
		/// <param name="parameters">Parameters for this task</param>
		public CloneVolumeTask(CloneVolumeTaskParameters parameters)
		{
			_parameters = parameters;
		}

		/// <summary>
		/// Execute the task.
		/// </summary>
		/// <param name="job">Information about the current job</param>
		/// <param name="buildProducts">Set of build products produced by this node.</param>
		/// <param name="tagNameToFileSet">Mapping from tag names to the set of files they include</param>
		public override void Execute(JobContext job, HashSet<FileReference> buildProducts, Dictionary<string, HashSet<FileReference>> tagNameToFileSet)
		{
			// Validate all required parameters
			ValidateParameters();

			Logger.LogInformation("Starting FlexClone volume creation");
			Logger.LogInformation("Source Volume: {SourceVolume}", _parameters.SourceVolume);
			Logger.LogInformation("Snapshot: {SnapshotName}", _parameters.SnapshotName);
			Logger.LogInformation("Clone Volume: {CloneVolumeName}", _parameters.CloneVolumeName);
			Logger.LogInformation("SVM: {SvmName}", _parameters.SvmName);

			try
			{
				CreateFlexCloneVolumeAsync().Wait();
				Logger.LogInformation("FlexClone volume creation completed successfully");
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to create FlexClone volume '{CloneVolumeName}'", _parameters.CloneVolumeName);
				throw;
			}
		}

		/// <summary>
		/// Validates that all required parameters are provided
		/// </summary>
		private void ValidateParameters()
		{
			if (String.IsNullOrEmpty(_parameters.SourceVolume))
			{
				throw new AutomationException("SourceVolume parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.SnapshotName))
			{
				throw new AutomationException("SnapshotName parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.CloneVolumeName))
			{
				throw new AutomationException("CloneVolumeName parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.SvmName))
			{
				throw new AutomationException("SvmName parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.FsxAdminIp))
			{
				throw new AutomationException("FsxAdminIp parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.OntapUser))
			{
				throw new AutomationException("OntapUser parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.AwsSecretName))
			{
				throw new AutomationException("AwsSecretName parameter is required");
			}
			if (String.IsNullOrEmpty(_parameters.AwsRegion))
			{
				throw new AutomationException("AwsRegion parameter is required");
			}
		}

		/// <summary>
		/// Creates a FlexClone volume from an existing snapshot
		/// </summary>
		private async Task CreateFlexCloneVolumeAsync()
		{
			try
			{
				// Create OntapUtils instance
				OntapUtils ontapUtils = new OntapUtils(
					_parameters.FsxAdminIp,
					_parameters.OntapUser,
					_parameters.AwsSecretName,
					_parameters.AwsRegion,
					Logger);

				// Verify source volume exists
				Logger.LogInformation("Verifying source volume '{SourceVolume}' exists...", _parameters.SourceVolume);
				bool sourceExists = await ontapUtils.VolumeExistsAsync(_parameters.SourceVolume, _parameters.SvmName);

				if (!sourceExists)
				{
					throw new AutomationException($"Source volume '{_parameters.SourceVolume}' not found in SVM '{_parameters.SvmName}'");
				}

				Logger.LogInformation("Source volume '{SourceVolume}' verified", _parameters.SourceVolume);

				// Check if clone volume already exists
				Logger.LogInformation("Checking if clone volume '{CloneVolumeName}' already exists...", _parameters.CloneVolumeName);
				bool cloneExists = await ontapUtils.VolumeExistsAsync(_parameters.CloneVolumeName, _parameters.SvmName);

				if (cloneExists)
				{
					throw new AutomationException($"Clone volume '{_parameters.CloneVolumeName}' already exists. Please delete it first or use a different name.");
				}

				// Create the FlexClone volume
				string cloneVolumeName = await ontapUtils.CreateFlexCloneVolumeAsync(
					_parameters.SourceVolume,
					_parameters.SnapshotName,
					_parameters.CloneVolumeName,
					_parameters.SvmName);

				Logger.LogInformation("FlexClone volume '{CloneVolumeName}' created successfully", cloneVolumeName);
				Logger.LogInformation("Junction Path: /{CloneVolumeName}", cloneVolumeName);
				Logger.LogInformation("✅ Full read/write regular NetApp volume");
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to create FlexClone volume");
				throw new AutomationException(ex, "Failed to create FlexClone volume");
			}
		}

		/// <summary>
		/// Output this task out to an XML writer.
		/// </summary>
		public override void Write(XmlWriter writer)
		{
			Write(writer, _parameters);
		}

		/// <summary>
		/// Find all the tags which are used as inputs to this task
		/// </summary>
		/// <returns>The tag names which are read by this task</returns>
		public override IEnumerable<string> FindConsumedTagNames()
		{
			return Enumerable.Empty<string>();
		}

		/// <summary>
		/// Find all the tags which are modified by this task
		/// </summary>
		/// <returns>The tag names which are modified by this task</returns>
		public override IEnumerable<string> FindProducedTagNames()
		{
			return Enumerable.Empty<string>();
		}
	}
}
