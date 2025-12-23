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
	/// Parameters for the SyncAndSnapshot task
	/// </summary>
	public class SyncAndSnapshotTaskParameters
	{
	/// <summary>
	/// The Perforce stream to sync from (e.g., //UE5/Release-5.3).
	/// </summary>
	[TaskParameter]
	public string Stream { get; set; }

		/// <summary>
		/// Perforce server and port (e.g., perforce:1666).
		/// </summary>
		[TaskParameter(Optional = true)]
		public string P4Port { get; set; }

		/// <summary>
		/// Perforce user name.
		/// </summary>
		[TaskParameter(Optional = true)]
		public string P4User { get; set; }

	/// <summary>
	/// Directory where files should be synced to. If not specified, uses current directory.
	/// </summary>
	[TaskParameter(Optional = true)]
	public string SyncDir { get; set; }

	/// <summary>
	/// Perforce workspace (client) name. If not specified, uses default workspace name.
	/// </summary>
	[TaskParameter(Optional = true)]
	public string WorkspaceName { get; set; }

	/// <summary>
	/// Name for the ONTAP snapshot to create. If not specified, no snapshot is created.
	/// </summary>
	[TaskParameter(Optional = true)]
	public string SnapshotName { get; set; }		/// <summary>
		/// FSx ONTAP management IP address.
		/// </summary>
		[TaskParameter(Optional = true)]
		public string FsxAdminIp { get; set; }

		/// <summary>
		/// ONTAP username (e.g., fsxadmin).
		/// </summary>
		[TaskParameter(Optional = true)]
		public string OntapUser { get; set; }

		/// <summary>
		/// AWS Secrets Manager secret name containing the FSx password.
		/// </summary>
		[TaskParameter(Optional = true)]
		public string AwsSecretName { get; set; }

		/// <summary>
		/// AWS region where the secret is stored.
		/// </summary>
		[TaskParameter(Optional = true)]
		public string AwsRegion { get; set; }

		/// <summary>
		/// ONTAP volume name where the snapshot should be created.
		/// </summary>
		[TaskParameter(Optional = true)]
		public string VolumeName { get; set; }
	}

	/// <summary>
	/// Syncs files from a Perforce stream and creates a snapshot.
	/// </summary>
	[TaskElement("SyncAndSnapshot", typeof(SyncAndSnapshotTaskParameters))]
	public class SyncAndSnapshotTask : CustomTask
	{
		/// <summary>
		/// Parameters for the task
		/// </summary>
		readonly SyncAndSnapshotTaskParameters _parameters;

		/// <summary>
		/// Constructor.
		/// </summary>
		/// <param name="parameters">Parameters for the task</param>
		public SyncAndSnapshotTask(SyncAndSnapshotTaskParameters parameters)
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
		// Build the sync path - always sync everything from the stream
		string syncPath = _parameters.Stream + "/...";

		Logger.LogInformation("Syncing from Perforce: {SyncPath}", syncPath);			// Save original directory
			string originalDir = Environment.CurrentDirectory;

			try
			{
				// Determine sync directory
				string syncDir = !String.IsNullOrEmpty(_parameters.SyncDir) ? _parameters.SyncDir : Environment.CurrentDirectory;
				
				if (!Directory.Exists(syncDir))
				{
					Logger.LogInformation("Creating sync directory: {SyncDir}", syncDir);
					Directory.CreateDirectory(syncDir);
				}

			// Create P4Connection with specified server/user or use defaults from P4Environment
			string p4User = _parameters.P4User ?? CommandUtils.P4Env.User;
			string p4Port = _parameters.P4Port ?? CommandUtils.P4Env.ServerAndPort;
			
			Logger.LogInformation("P4 User: {P4User}, P4 Port: {P4Port}", p4User, p4Port);
			
			P4Connection submitP4;
			if (_parameters.WorkspaceName != null)
			{
				Logger.LogInformation("Creating/updating workspace '{WorkspaceName}'", _parameters.WorkspaceName);
				
				// Create a brand new workspace
				P4ClientInfo client = new P4ClientInfo();
				client.Owner = p4User;
				client.Host = Unreal.MachineName;
				client.RootPath = syncDir;
				client.Name = _parameters.WorkspaceName;
				client.Options = P4ClientOption.NoAllWrite | P4ClientOption.NoClobber | P4ClientOption.NoCompress | P4ClientOption.Unlocked | P4ClientOption.NoModTime | P4ClientOption.NoRmDir;
				client.SubmitOptions = P4SubmitOption.SubmitUnchanged;
				client.LineEnd = P4LineEnd.Local;
				client.Stream = _parameters.Stream;
				
				// Create the workspace using a temporary connection
				P4Connection tempP4 = new P4Connection(p4User, null, p4Port);
				tempP4.CreateClient(client, AllowSpew: true);
				Logger.LogInformation("Successfully created/updated workspace '{Workspace}'", _parameters.WorkspaceName);

				// Create a new connection for it
				submitP4 = new P4Connection(client.Owner, client.Name, p4Port);
				Logger.LogInformation("Created P4Connection with user '{User}', client '{Client}', port '{Port}'", client.Owner, client.Name, p4Port);
			}
			else
			{
				// Use default connection or create one
				submitP4 = new P4Connection(p4User, null, p4Port);
				Logger.LogInformation("Using default P4Connection with user '{User}', port '{Port}'", p4User, p4Port);
			}

			// Change to sync directory
			Environment.CurrentDirectory = syncDir ?? Environment.CurrentDirectory;
			Logger.LogInformation("Changed to sync directory: {SyncDir}", syncDir);

			// Perform the sync
			Logger.LogInformation("Syncing: {SyncPath}", syncPath);
			submitP4.Sync(syncPath, AllowSpew: true);

			Logger.LogInformation("Successfully synced from {Stream}", _parameters.Stream);

				// Create ONTAP snapshot if SnapshotName is provided
				if (!String.IsNullOrEmpty(_parameters.SnapshotName))
				{
					// Validate all required snapshot parameters are provided
					if (String.IsNullOrEmpty(_parameters.FsxAdminIp))
					{
						throw new AutomationException("SnapshotName is specified but FsxAdminIp is missing. All snapshot parameters are required when creating a snapshot.");
					}
					if (String.IsNullOrEmpty(_parameters.OntapUser))
					{
						throw new AutomationException("SnapshotName is specified but OntapUser is missing. All snapshot parameters are required when creating a snapshot.");
					}
					if (String.IsNullOrEmpty(_parameters.AwsSecretName))
					{
						throw new AutomationException("SnapshotName is specified but AwsSecretName is missing. All snapshot parameters are required when creating a snapshot.");
					}
					if (String.IsNullOrEmpty(_parameters.AwsRegion))
					{
						throw new AutomationException("SnapshotName is specified but AwsRegion is missing. All snapshot parameters are required when creating a snapshot.");
					}
					if (String.IsNullOrEmpty(_parameters.VolumeName))
					{
						throw new AutomationException("SnapshotName is specified but VolumeName is missing. All snapshot parameters are required when creating a snapshot.");
					}
					
					CreateOntapSnapshotAsync().Wait();
				}
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to sync from Perforce stream {Stream}", _parameters.Stream);
				throw;
			}
			finally
			{
				// Restore original directory
				Environment.CurrentDirectory = originalDir;
			}
		}

		/// <summary>
		/// Creates an ONTAP snapshot
		/// </summary>
		private async Task CreateOntapSnapshotAsync()
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

				// Create the snapshot
				string snapshotName = await ontapUtils.CreateOntapSnapshotAsync(_parameters.VolumeName, _parameters.SnapshotName);

				Logger.LogInformation("ONTAP snapshot '{SnapshotName}' created successfully", snapshotName);
			}
			catch (Exception ex)
			{
				Logger.LogError(ex, "Failed to create ONTAP snapshot");
				throw;
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
