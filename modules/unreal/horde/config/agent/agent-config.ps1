<powershell>
# Enlarge all file systems to fill the EBS volumes
(Get-PSDrive -PSProvider FileSystem).Name | ForEach-Object { Resize-Partition -DriveLetter $_ -Size $(Get-PartitionSupportedSize -DriveLetter $_).SizeMax -ErrorAction SilentlyContinue }

# Install the necessary dotnet runtime
choco install -y --no-progress dotnet-${dotnet_runtime_version}-runtime

# Windows doesn't support RBN so we do it manually
# NetBIOS name max length is 15 bytes so we need to truncate the instance id
$instanceid = @(Get-EC2InstanceMetadata -Category InstanceId)[0].Substring(2, 15)
Rename-Computer $instanceid

# Download and unzip the agent
$hordedir = "C:\Horde"
Invoke-WebRequest -Uri https://${fully_qualified_domain_name}/api/v1/tools/horde-agent?action=Zip -OutFile C:\HordeAgent.zip
Expand-Archive -LiteralPath C:\HordeAgent.zip -DestinationPath $hordedir -Force

# Write the config file
@{
    "Horde" = @{
        "Name" = $instanceid;
        "EnableAwsEc2Support" = $true;
    };
} | ConvertTo-Json -depth 100 | Out-File "$hordedir\appsettings.User.json"

# If necessary, fetch the p4trust file
%{if p4_trust_bucket != null}
Read-S3Object -BucketName ${p4_trust_bucket} -Key agent/.p4trust -File $hordedir\p4trust.txt
[Environment]::SetEnvironmentVariable("P4TRUST", "$hordedir\p4trust.txt", "Machine")
%{endif}

# Configure and start the agent
& "$hordedir\HordeAgent.exe" SetServer -Default -Url="https://${fully_qualified_domain_name}"
& "$hordedir\HordeAgent.exe" Service Install -Start=false

# Schedule a reboot in 5 minutes
shutdown /r /d p:4:2 /t $(60*5)
</powershell>
