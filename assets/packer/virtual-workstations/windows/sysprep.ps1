$ErrorActionPreference = "Stop"

Write-Host "Configuring EC2Launch v2 for password retrieval (minimal config)..."

# Create EC2Launch v2 config directory
New-Item -Path "C:\ProgramData\Amazon\EC2Launch\config" -ItemType Directory -Force | Out-Null

# EC2Launch v2 config - Sets random hostname and password, configures DNS suffixes for Active Directory administration
$agentConfig = @'
version: 1.0
config:
  - stage: boot
    tasks:
      - task: extendRootPartition
  - stage: preReady
    tasks:
      - task: setDnsSuffix
        inputs:
          suffixes:
            # add your domain suffixes here(my.domain.com)
      - task: setAdminAccount
        inputs:
          password:
            type: random
  - stage: postReady
    tasks:
      - task: startSsm
      - task: setHostName
        inputs:
          reboot: false
'@

$agentConfig | Out-File -FilePath "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml" -Encoding UTF8 -Force

Write-Host "EC2Launch v2 configuration applied"
