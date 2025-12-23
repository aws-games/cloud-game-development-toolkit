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
	/// Parameters for the DeleteSnapshot task
	/// </summary>
	public class DeleteSnapshotTaskParameters
	{
		/// <summary>
		/// Name of the volume containing the snapshot.
		/// </summary>
		[TaskParameter]
		public string VolumeName { get; set; }

		/// <summary>
		/// Name of the snapshot to delete.
		/// </summary>
		[TaskParameter]
		public string SnapshotName { get; set; }

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
	/// Deletes an ONTAP snapshot.
	/// </summary>
	[TaskElement("DeleteSnapshot", typeof(DeleteSnapshotTaskParameters))]
	public class DeleteSnapshotTask : CustomTask
	{
		/// <summary>
		/// Parameters for the task
		/// </summary>
		private readonly DeleteSnapshotTaskParameters _parameters;

		/// <summary>
		/// Constructor
		/// </summary>
		/// <param name="parameters">Parameters for this task</param>
		public DeleteSnapshotTask(DeleteSnapshotTaskParameters parameters)
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
			Logger.LogInformation("Starting ONTAP snapshot deletion");
			Logger.LogInformation("Volume: {VolumeName}", _parameters.VolumeName);
			Logger.LogInformation("Snapshot: {SnapshotName}", _parameters.SnapshotName);

			try
			{
				DeleteSnapshotAsync().Wait();
				Logger.LogInformation("Snapshot deletion completed successfully");
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to delete snapshot '{SnapshotName}' from volume '{VolumeName}'", _parameters.SnapshotName, _parameters.VolumeName);
				throw;
			}
		}

		/// <summary>
		/// Deletes an ONTAP snapshot
		/// </summary>
		private async Task DeleteSnapshotAsync()
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

				// Delete the snapshot
				await ontapUtils.DeleteSnapshotAsync(_parameters.VolumeName, _parameters.SnapshotName);

				Logger.LogInformation("Snapshot '{SnapshotName}' deleted successfully from volume '{VolumeName}'", _parameters.SnapshotName, _parameters.VolumeName);
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to delete ONTAP snapshot");
				throw new AutomationException(ex, "Failed to delete ONTAP snapshot");
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
