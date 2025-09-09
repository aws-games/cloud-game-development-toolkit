$ErrorActionPreference = "Stop"

Write-Host "Configuring EC2Launch for password retrieval (minimal config)..."

# Create EC2Launch config directory
New-Item -Path "C:\ProgramData\Amazon\EC2Launch\config" -ItemType Directory -Force | Out-Null

# EC2Launch v1 config - Sets random password and basic configuration
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
            - ec2.internal
      - task: setAdminAccount
        inputs:
          password:
            type: random
  - stage: postReady
    tasks:
      - task: startSsm
'@

$agentConfig | Out-File -FilePath "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml" -Encoding UTF8 -Force

Write-Host "EC2Launch configuration applied"