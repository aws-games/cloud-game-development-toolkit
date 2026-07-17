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

%{if p4_port != null}
# Install the Perforce command-line client. Unreal Engine build steps (BuildGraph,
# BuildCookRun) shell out to p4.exe, which is not present on a stock VDI/agent AMI.
choco install -y --no-progress p4
%{endif}

%{if enable_long_paths}
# Enable NTFS long-path support. From-source Unreal Engine builds generate deeply nested
# response-file paths that blow past MAX_PATH for link.exe/cl.exe (LNK1104 "cannot open
# *.rsp"). This is a generic, value-free, machine-local setting.
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force | Out-Null
%{endif}

%{if uba_compute_ports != null}
# Open the host Windows Firewall for UBA (Unreal Build Accelerator) distributed compile
# workers. The agent security group must also permit this range; the host firewall is the
# part that is otherwise missed, causing remote workers to time out and fall back to local.
if (-not (Get-NetFirewallRule -DisplayName 'Horde UBA Compute ${uba_compute_ports}' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'Horde UBA Compute ${uba_compute_ports}' -Direction Inbound -Action Allow -Protocol TCP -LocalPort ${uba_compute_ports} -Profile Any | Out-Null
}
%{endif}

%{if uba_horde_pool != null}
# Configure UBA-over-Horde for UnrealBuildTool, written to the LocalSystem profile that the
# Horde agent service runs under. NOTE: <Horde> is a TOP-LEVEL element (sibling of
# <UnrealBuildAccelerator>), NOT a child of it; nesting it is silently ignored.
$ubtDir = "$env:WINDIR\System32\config\systemprofile\AppData\Roaming\Unreal Engine\UnrealBuildTool"
New-Item -ItemType Directory -Path $ubtDir -Force | Out-Null
@"
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
  <BuildConfiguration>
    <bAllowUBAExecutor>true</bAllowUBAExecutor>
  </BuildConfiguration>
  <Horde>
    <Server>https://${fully_qualified_domain_name}</Server>
    <Cluster>default</Cluster>
    <WindowsPool>${uba_horde_pool}</WindowsPool>
    <ConnectionMode>Relay</ConnectionMode>
    <MaxWorkers>${uba_max_workers}</MaxWorkers>
  </Horde>
</Configuration>
"@ | Out-File -FilePath (Join-Path $ubtDir 'BuildConfiguration.xml') -Encoding utf8
%{endif}

# Write a DURABLE agent.json under ProgramData. The 5.7+ agent self-upgrade rewrites
# C:\Horde\appsettings.json to an empty document, which strands the agent at localhost:5000
# (losing the URL set by SetServer below). Recording the server profile here keeps the agent
# pointed at the right server across upgrades.%{ if agent_working_dir != null } A short
# WorkingDir also keeps engine-plugin paths under MAX_PATH.%{ endif }
$agentJsonDir = "C:\ProgramData\Epic\Horde\Agent"
New-Item -ItemType Directory -Path $agentJsonDir -Force | Out-Null
@{
    "Horde" = @{
        "Server" = "Default";
        "ServerProfiles" = @(@{
            "Name" = "Default";
            "Environment" = "Production";
            "Url" = "https://${fully_qualified_domain_name}";
        });
%{ if agent_working_dir != null }
        "WorkingDir" = "${agent_working_dir}";
%{ endif }
    };
} | ConvertTo-Json -depth 100 | Out-File "$agentJsonDir\agent.json" -Encoding utf8

# Configure and start the agent
& "$hordedir\HordeAgent.exe" SetServer -Default -Url="https://${fully_qualified_domain_name}"
& "$hordedir\HordeAgent.exe" Service Install -Start=false

# Schedule a reboot in 5 minutes
shutdown /r /d p:4:2 /t $(60*5)
</powershell>
