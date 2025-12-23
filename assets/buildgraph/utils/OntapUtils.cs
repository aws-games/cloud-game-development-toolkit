using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using AutomationUtils;
using EpicGames.Core;
using Microsoft.Extensions.Logging;

namespace AutomationTool
{
	/// <summary>
	/// Helper class for NetApp ONTAP operations
	/// </summary>
	public class OntapUtils
	{
		private readonly string _fsxAdminIp;
		private readonly string _ontapUser;
		private readonly string _ontapPasswordSecretName;
		private readonly string _awsRegion;
		private readonly ILogger _logger;
		private string _password;

		/// <summary>
		/// Constructor
		/// </summary>
		/// <param name="fsxAdminIp">FSx ONTAP management IP address</param>
		/// <param name="ontapUser">ONTAP username</param>
		/// <param name="ontapPasswordSecretName">AWS Secrets Manager secret name containing the FSx password</param>
		/// <param name="awsRegion">AWS region where the secret is stored</param>
		/// <param name="logger">Logger for output</param>
		public OntapUtils(string fsxAdminIp, string ontapUser, string ontapPasswordSecretName, string awsRegion, ILogger logger)
		{
			_fsxAdminIp = fsxAdminIp;
			_ontapUser = ontapUser;
			_ontapPasswordSecretName = ontapPasswordSecretName;
			_awsRegion = awsRegion;
			_logger = logger;
		}

		/// <summary>
		/// Ensures the password is retrieved from AWS Secrets Manager (lazy loading)
		/// </summary>
		private async Task EnsurePasswordAsync(CancellationToken cancellationToken = default)
		{
			if (_password == null)
			{
				_password = await GetAwsSecretAsync(_ontapPasswordSecretName, _awsRegion, _logger, cancellationToken);
			}
		}

		/// <summary>
		/// Gets a secret value from AWS Secrets Manager using AWS CLI
		/// </summary>
		private static async Task<string> GetAwsSecretAsync(string secretName, string region, ILogger logger, CancellationToken cancellationToken = default)
		{
			return await Task.Run(() =>
			{
				try
				{
					// Use AWS CLI to get the secret
					string arguments = $"secretsmanager get-secret-value --secret-id \"{secretName}\" --region {region} --query SecretString --output text";
					
					IProcessResult result = CommandUtils.Run("aws", arguments, Options: CommandUtils.ERunOptions.Default);

					string secretValue = result.Output.Trim();
					
					if (string.IsNullOrEmpty(secretValue))
					{
						throw new AutomationException($"AWS secret '{secretName}' is empty");
					}

					logger.LogInformation("Successfully retrieved secret '{SecretName}'", secretName);
					return secretValue;
				}
				catch (Exception ex)
				{
					logger.LogError(ex, "Failed to get AWS secret '{SecretName}'", secretName);
					throw new AutomationException(ex, $"Failed to get AWS secret '{secretName}'");
				}
			}, cancellationToken);
		}

		/// <summary>
		/// Gets the UUID of an ONTAP volume
		/// </summary>
		private async Task<string> GetVolumeUuidAsync(string volumeName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Getting UUID for volume '{VolumeName}'...", volumeName);

			await EnsurePasswordAsync(cancellationToken);
			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);
			
			string url = $"https://{_fsxAdminIp}/api/storage/volumes?name={volumeName}&fields=uuid";
			
			try
			{
				HttpResponseMessage response = await client.GetAsync(url, cancellationToken);
				response.EnsureSuccessStatusCode();

				string jsonResponse = await response.Content.ReadAsStringAsync(cancellationToken);
				using JsonDocument doc = JsonDocument.Parse(jsonResponse);
				
				JsonElement root = doc.RootElement;
				if (root.TryGetProperty("records", out JsonElement records) && records.GetArrayLength() > 0)
				{
					JsonElement firstRecord = records[0];
					if (firstRecord.TryGetProperty("uuid", out JsonElement uuidElement))
					{
						string uuid = uuidElement.GetString();
						_logger.LogInformation("Volume UUID for '{VolumeName}': {Uuid}", volumeName, uuid);
						return uuid;
					}
				}

				throw new AutomationException($"Could not find UUID for volume '{volumeName}'");
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to get UUID for volume '{VolumeName}'", volumeName);
				throw new AutomationException(ex, $"Failed to get UUID for volume '{volumeName}'");
			}
		}

		/// <summary>
		/// Creates a snapshot of an ONTAP volume
		/// </summary>
		/// <param name="volumeName">Name of the volume to snapshot</param>
		/// <param name="snapshotName">Name for the new snapshot</param>
		/// <param name="cancellationToken">Cancellation token</param>
		/// <returns>The snapshot name if successful</returns>
		public async Task<string> CreateOntapSnapshotAsync(string volumeName, string snapshotName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Creating NetApp snapshot '{SnapshotName}' for volume '{VolumeName}'...", snapshotName, volumeName);

			await EnsurePasswordAsync(cancellationToken);

			// Get volume UUID
			string volumeUuid = await GetVolumeUuidAsync(volumeName, cancellationToken);

			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);

			// Check if snapshot already exists
			_logger.LogInformation("Checking if snapshot '{SnapshotName}' already exists...", snapshotName);
			string checkUrl = $"https://{_fsxAdminIp}/api/storage/volumes/{volumeUuid}/snapshots?name={snapshotName}";
			
			try
			{
				HttpResponseMessage checkResponse = await client.GetAsync(checkUrl, cancellationToken);
				checkResponse.EnsureSuccessStatusCode();

				string checkJson = await checkResponse.Content.ReadAsStringAsync(cancellationToken);
				using JsonDocument checkDoc = JsonDocument.Parse(checkJson);
				
				if (checkDoc.RootElement.TryGetProperty("records", out JsonElement records) && records.GetArrayLength() > 0)
				{
					_logger.LogInformation("Snapshot '{SnapshotName}' already exists on volume '{VolumeName}'", snapshotName, volumeName);
					return snapshotName;
				}
			}
			catch (Exception ex)
			{
				_logger.LogWarning(ex, "Failed to check if snapshot exists, will attempt to create it");
			}

			// Create snapshot
			_logger.LogInformation("Creating snapshot '{SnapshotName}'...", snapshotName);
			string createUrl = $"https://{_fsxAdminIp}/api/storage/volumes/{volumeUuid}/snapshots";
			
			var snapshotData = new
			{
				name = snapshotName
			};

			string jsonContent = JsonSerializer.Serialize(snapshotData);
			using StringContent content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

			try
			{
				HttpResponseMessage createResponse = await client.PostAsync(createUrl, content, cancellationToken);
				
				string responseBody = await createResponse.Content.ReadAsStringAsync(cancellationToken);
				
				if (!createResponse.IsSuccessStatusCode)
				{
					_logger.LogError("Failed to create snapshot. Status: {StatusCode}, Response: {Response}", createResponse.StatusCode, responseBody);
					throw new AutomationException($"Failed to create snapshot '{snapshotName}'. Status: {createResponse.StatusCode}");
				}

				_logger.LogInformation("Snapshot '{SnapshotName}' created successfully on volume '{VolumeName}'", snapshotName, volumeName);

				// Wait for snapshot to be ready
				await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);

				// Verify snapshot was created
				_logger.LogInformation("Verifying snapshot '{SnapshotName}'...", snapshotName);
				HttpResponseMessage verifyResponse = await client.GetAsync(checkUrl, cancellationToken);
				verifyResponse.EnsureSuccessStatusCode();

				string verifyJson = await verifyResponse.Content.ReadAsStringAsync(cancellationToken);
				using JsonDocument verifyDoc = JsonDocument.Parse(verifyJson);
				
				if (verifyDoc.RootElement.TryGetProperty("records", out JsonElement verifyRecords) && verifyRecords.GetArrayLength() > 0)
				{
					_logger.LogInformation("Snapshot '{SnapshotName}' verified and ready", snapshotName);
					return snapshotName;
				}

				throw new AutomationException($"Snapshot '{snapshotName}' verification failed");
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to create snapshot '{SnapshotName}'", snapshotName);
				throw new AutomationException(ex, $"Failed to create snapshot '{snapshotName}'");
			}
		}

		/// <summary>
		/// Checks if a volume exists in ONTAP
		/// </summary>
		/// <param name="volumeName">Name of the volume to check</param>
		/// <param name="svmName">Storage Virtual Machine name (optional)</param>
		/// <param name="cancellationToken">Cancellation token</param>
		/// <returns>True if volume exists, false otherwise</returns>
		public async Task<bool> VolumeExistsAsync(string volumeName, string svmName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Checking if volume '{VolumeName}' exists...", volumeName);

			await EnsurePasswordAsync(cancellationToken);
			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);
			
			string url = $"https://{_fsxAdminIp}/api/storage/volumes?name={volumeName}";
			if (!String.IsNullOrEmpty(svmName))
			{
				url += $"&svm.name={svmName}";
			}
			
			try
			{
				HttpResponseMessage response = await client.GetAsync(url, cancellationToken);
				response.EnsureSuccessStatusCode();

				string jsonResponse = await response.Content.ReadAsStringAsync(cancellationToken);
				using JsonDocument doc = JsonDocument.Parse(jsonResponse);
				
				JsonElement root = doc.RootElement;
				if (root.TryGetProperty("records", out JsonElement records) && records.GetArrayLength() > 0)
				{
					_logger.LogInformation("Volume '{VolumeName}' exists", volumeName);
					return true;
				}

				_logger.LogInformation("Volume '{VolumeName}' does not exist", volumeName);
				return false;
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to check if volume '{VolumeName}' exists", volumeName);
				throw new AutomationException(ex, $"Failed to check if volume '{volumeName}' exists");
			}
		}

		/// <summary>
		/// Deletes a volume from ONTAP
		/// </summary>
		/// <param name="volumeName">Name of the volume to delete</param>
		/// <param name="cancellationToken">Cancellation token</param>
		public async Task DeleteVolumeAsync(string volumeName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Deleting volume '{VolumeName}'...", volumeName);

			await EnsurePasswordAsync(cancellationToken);

			// First get the volume UUID
			string volumeUuid = await GetVolumeUuidAsync(volumeName, cancellationToken);

			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);
			
			string url = $"https://{_fsxAdminIp}/api/storage/volumes/{volumeUuid}";
			
			try
			{
				HttpResponseMessage response = await client.DeleteAsync(url, cancellationToken);
				
				string responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
				
				if (!response.IsSuccessStatusCode)
				{
					_logger.LogError("Failed to delete volume. Status: {StatusCode}, Response: {Response}", response.StatusCode, responseBody);
					throw new AutomationException($"Failed to delete volume '{volumeName}'. Status: {response.StatusCode}");
				}

				_logger.LogInformation("Volume '{VolumeName}' deleted successfully", volumeName);
				
				// Wait for deletion to complete
				await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to delete volume '{VolumeName}'", volumeName);
				throw new AutomationException(ex, $"Failed to delete volume '{volumeName}'");
			}
		}

		/// <summary>
		/// Creates a FlexClone volume from an existing snapshot
		/// </summary>
		/// <param name="sourceVolumeName">Name of the source volume</param>
		/// <param name="snapshotName">Name of the snapshot to clone from</param>
		/// <param name="cloneVolumeName">Name for the new FlexClone volume</param>
		/// <param name="svmName">Storage Virtual Machine name</param>
		/// <param name="cancellationToken">Cancellation token</param>
		/// <returns>The clone volume name if successful</returns>
		public async Task<string> CreateFlexCloneVolumeAsync(string sourceVolumeName, string snapshotName, string cloneVolumeName, string svmName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Creating FlexClone volume '{CloneVolumeName}' from snapshot '{SnapshotName}' on source volume '{SourceVolumeName}'...", 
				cloneVolumeName, snapshotName, sourceVolumeName);

			await EnsurePasswordAsync(cancellationToken);
			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);

			// Check if clone volume already exists
			if (await VolumeExistsAsync(cloneVolumeName, svmName, cancellationToken))
			{
				throw new AutomationException($"Clone volume '{cloneVolumeName}' already exists. Please delete it first or use a different name.");
			}

			// Create FlexClone volume
			_logger.LogInformation("Creating FlexClone volume '{CloneVolumeName}'...", cloneVolumeName);
			string createUrl = $"https://{_fsxAdminIp}/api/storage/volumes";
			
			var cloneData = new
			{
				name = cloneVolumeName,
				svm = new
				{
					name = svmName
				},
				clone = new
				{
					is_flexclone = true,
					parent_snapshot = new
					{
						name = snapshotName
					},
					parent_volume = new
					{
						name = sourceVolumeName
					}
				},
				comment = $"FlexClone from snapshot {snapshotName}"
			};

			string jsonContent = JsonSerializer.Serialize(cloneData);
			using StringContent content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

			try
			{
				HttpResponseMessage createResponse = await client.PostAsync(createUrl, content, cancellationToken);
				
				string responseBody = await createResponse.Content.ReadAsStringAsync(cancellationToken);
				
				if (!createResponse.IsSuccessStatusCode)
				{
					_logger.LogError("Failed to create FlexClone volume. Status: {StatusCode}, Response: {Response}", createResponse.StatusCode, responseBody);
					throw new AutomationException($"Failed to create FlexClone volume '{cloneVolumeName}'. Status: {createResponse.StatusCode}");
				}

				_logger.LogInformation("FlexClone volume '{CloneVolumeName}' created successfully", cloneVolumeName);

				// Wait for volume to be ready
				await Task.Delay(TimeSpan.FromSeconds(10), cancellationToken);

				// Verify volume was created
				_logger.LogInformation("Verifying FlexClone volume '{CloneVolumeName}'...", cloneVolumeName);
				if (await VolumeExistsAsync(cloneVolumeName, svmName, cancellationToken))
				{
					_logger.LogInformation("FlexClone volume '{CloneVolumeName}' verified and ready", cloneVolumeName);
					return cloneVolumeName;
				}

				throw new AutomationException($"FlexClone volume '{cloneVolumeName}' verification failed");
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to create FlexClone volume '{CloneVolumeName}'", cloneVolumeName);
				throw new AutomationException(ex, $"Failed to create FlexClone volume '{cloneVolumeName}'");
			}
		}

		/// <summary>
		/// Deletes an ONTAP snapshot
		/// </summary>
		/// <param name="volumeName">Name of the volume containing the snapshot</param>
		/// <param name="snapshotName">Name of the snapshot to delete</param>
		/// <param name="cancellationToken">Cancellation token</param>
		public async Task DeleteSnapshotAsync(string volumeName, string snapshotName, CancellationToken cancellationToken = default)
		{
			_logger.LogInformation("Deleting snapshot '{SnapshotName}' from volume '{VolumeName}'...", snapshotName, volumeName);

			await EnsurePasswordAsync(cancellationToken);

			// Get volume UUID
			string volumeUuid = await GetVolumeUuidAsync(volumeName, cancellationToken);

			using HttpClient client = CreateOntapHttpClient(_ontapUser, _password);
			
			// Get snapshot UUID
			string getUrl = $"https://{_fsxAdminIp}/api/storage/volumes/{volumeUuid}/snapshots?name={snapshotName}";
			
			try
			{
				HttpResponseMessage getResponse = await client.GetAsync(getUrl, cancellationToken);
				getResponse.EnsureSuccessStatusCode();

				string jsonResponse = await getResponse.Content.ReadAsStringAsync(cancellationToken);
				using JsonDocument doc = JsonDocument.Parse(jsonResponse);
				
				JsonElement root = doc.RootElement;
				if (root.TryGetProperty("records", out JsonElement records) && records.GetArrayLength() > 0)
				{
					JsonElement firstRecord = records[0];
					if (firstRecord.TryGetProperty("uuid", out JsonElement uuidElement))
					{
						string snapshotUuid = uuidElement.GetString();
						_logger.LogInformation("Found snapshot '{SnapshotName}' with UUID: {Uuid}", snapshotName, snapshotUuid);

						// Delete the snapshot
						string deleteUrl = $"https://{_fsxAdminIp}/api/storage/volumes/{volumeUuid}/snapshots/{snapshotUuid}";
						HttpResponseMessage deleteResponse = await client.DeleteAsync(deleteUrl, cancellationToken);
						deleteResponse.EnsureSuccessStatusCode();

						_logger.LogInformation("Snapshot '{SnapshotName}' deleted successfully", snapshotName);
						return;
					}
				}

				throw new AutomationException($"Snapshot '{snapshotName}' not found on volume '{volumeName}'");
			}
			catch (Exception ex)
			{
				_logger.LogError(ex, "Failed to delete snapshot '{SnapshotName}' from volume '{VolumeName}'", snapshotName, volumeName);
				throw new AutomationException(ex, $"Failed to delete snapshot '{snapshotName}' from volume '{volumeName}'");
			}
		}

		/// <summary>
		/// Creates an HttpClient configured for ONTAP API calls
		/// </summary>
		private static HttpClient CreateOntapHttpClient(string username, string password)
		{
			// Create handler that bypasses SSL certificate validation
			HttpClientHandler handler = new HttpClientHandler
			{
				ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true
			};
			
			HttpClient client = new HttpClient(handler);
			
			// Set basic authentication
			string credentials = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{username}:{password}"));
			client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", credentials);
			
			// Set timeout
			client.Timeout = TimeSpan.FromSeconds(30);

			return client;
		}
	}
}
