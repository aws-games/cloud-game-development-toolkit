using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Xml;
using EpicGames.Core;
using Microsoft.Extensions.Logging;
using UnrealBuildBase;

namespace AutomationTool.Tasks
{
	/// <summary>
	/// Parameters for the DeleteVolume task
	/// </summary>
	public class DeleteVolumeTaskParameters
	{
		/// <summary>
		/// Name of the volume to delete.
		/// </summary>
		[TaskParameter]
		public string VolumeName { get; set; }

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
		public string OntapPasswordSecretName { get; set; }

		/// <summary>
		/// AWS region where the secret is stored.
		/// </summary>
		[TaskParameter]
		public string AwsRegion { get; set; }
	}

	/// <summary>
	/// Deletes an ONTAP volume.
	/// </summary>
	[TaskElement("DeleteVolume", typeof(DeleteVolumeTaskParameters))]
	public class DeleteVolumeTask : CustomTask
	{
		/// <summary>
		/// Parameters for the task
		/// </summary>
		private readonly DeleteVolumeTaskParameters _parameters;

		/// <summary>
		/// Constructor
		/// </summary>
		/// <param name="parameters">Parameters for this task</param>
		public DeleteVolumeTask(DeleteVolumeTaskParameters parameters)
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
			Logger.LogInformation("Starting ONTAP volume deletion");
			Logger.LogInformation("Volume: {VolumeName}", _parameters.VolumeName);
			Logger.LogInformation("SVM: {SvmName}", _parameters.SvmName);

			try
			{
				DeleteVolumeAsync().Wait();
				Logger.LogInformation("Volume deletion completed successfully");
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to delete volume '{VolumeName}'", _parameters.VolumeName);
				throw;
			}
		}

		/// <summary>
		/// Deletes an ONTAP volume
		/// </summary>
		private async Task DeleteVolumeAsync()
		{
			try
			{
				// Create OntapUtils instance
				OntapUtils ontapUtils = new OntapUtils(
					_parameters.FsxAdminIp,
					_parameters.OntapUser,
					_parameters.OntapPasswordSecretName,
					_parameters.AwsRegion,
					Logger);

				// Delete the volume
				await ontapUtils.DeleteVolumeAsync(_parameters.VolumeName);

				Logger.LogInformation("Volume '{VolumeName}' deleted successfully", _parameters.VolumeName);
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to delete ONTAP volume");
				throw new AutomationException(ex, "Failed to delete ONTAP volume");
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
