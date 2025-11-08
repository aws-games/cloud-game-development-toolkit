<powershell>
# Enlarge all file systems to fill the EBS volumes
(Get-PSDrive -PSProvider FileSystem).Name | ForEach-Object { Resize-Partition -DriveLetter $_ -Size $(Get-PartitionSupportedSize -DriveLetter $_).SizeMax }

# If necessary, fetch the p4trust file
%{if p4_trust_bucket != null}
Read-S3Object -BucketName ${p4_trust_bucket} -Key agent/.p4trust -File $Env:USERPROFILE\p4trust.txt
%{endif}

# Install the necessary dotnet runtime
choco install -y --no-progress dotnet-${dotnet_runtime_version}-runtime

# Name the agent after the EC2 InstanceId
# Note: this value could also go in the config file or environment, but this seems to be the most persistent storage method.
New-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Epic Games\Horde\Agent' -Name 'Name' -Value @(Get-EC2InstanceMetadata -Category InstanceId) -Force

# Download and unzip the agent
Invoke-WebRequest -Uri https://${fully_qualified_domain_name}/api/v1/tools/horde-agent?action=Zip -OutFile C:\HordeAgent.zip
Expand-Archive -LiteralPath C:\HordeAgent.zip -DestinationPath C:\Horde -Force

# Configure and start the agent
dotnet C:\Horde\HordeAgent.dll SetServer -Default -Url="https://${fully_qualified_domain_name}"
dotnet C:\Horde\HordeAgent.dll Service Install
</powershell>
<persist>true</persist>
