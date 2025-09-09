# SSM Documents for Software Installation

# Upload installation scripts to S3
resource "aws_s3_object" "installation_scripts" {
  for_each = fileset("${path.module}/assets/scripts/runtime", "*.ps1")
  
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/runtime/${each.value}"
  source = "${path.module}/assets/scripts/runtime/${each.value}"
  etag   = filemd5("${path.module}/assets/scripts/runtime/${each.value}")
  
  tags = {
    Purpose = "Installation Script"
    Script  = each.value
  }
}

# Upload custom scripts to S3
resource "aws_s3_object" "custom_scripts" {
  for_each = local.local_scripts_to_upload
  
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/custom/${each.key}"
  source = each.value.local_path
  etag   = filemd5(each.value.local_path)
  
  tags = {
    Purpose = "Custom Script"
    Script  = each.key
  }
}

# SSM Document for Chocolatey setup
resource "aws_ssm_document" "setup_chocolatey" {
  name          = "${local.name_prefix}-setup-chocolatey"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Setup Chocolatey package manager"
    parameters = {
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "setupChocolatey"
      inputs = {
        timeoutSeconds = "3600"
        runCommand = [
          "aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/runtime/setup-chocolatey.ps1 C:\\temp\\setup-chocolatey.ps1",
          "PowerShell.exe -ExecutionPolicy Bypass -File C:\\temp\\setup-chocolatey.ps1 -LogGroup '{{ LogGroup }}'"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Software Installation"
    Type    = "Chocolatey Setup"
  })
}

# SSM Document for Visual Studio installation
resource "aws_ssm_document" "install_visual_studio" {
  name          = "${local.name_prefix}-install-visual-studio"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install Visual Studio 2022"
    parameters = {
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "installVisualStudio"
      inputs = {
        timeoutSeconds = "7200"
        runCommand = [
          "aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/runtime/install-visual-studio.ps1 C:\\temp\\install-visual-studio.ps1",
          "PowerShell.exe -ExecutionPolicy Bypass -File C:\\temp\\install-visual-studio.ps1 -LogGroup '{{ LogGroup }}'"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Software Installation"
    Type    = "Visual Studio"
  })
}

# SSM Document for Git installation
resource "aws_ssm_document" "install_git" {
  name          = "${local.name_prefix}-install-git"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install Git"
    parameters = {
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "installGit"
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/runtime/install-git.ps1 C:\\temp\\install-git.ps1",
          "PowerShell.exe -ExecutionPolicy Bypass -File C:\\temp\\install-git.ps1 -LogGroup '{{ LogGroup }}'"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Software Installation"
    Type    = "Git"
  })
}

# SSM Document for Unreal Engine installation
resource "aws_ssm_document" "install_unreal_engine" {
  name          = "${local.name_prefix}-install-unreal-engine"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install Unreal Engine 5.3"
    parameters = {
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "installUnrealEngine"
      inputs = {
        timeoutSeconds = "3600"
        runCommand = [
          "aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/runtime/install-unreal-engine.ps1 C:\\temp\\install-unreal-engine.ps1",
          "PowerShell.exe -ExecutionPolicy Bypass -File C:\\temp\\install-unreal-engine.ps1 -LogGroup '{{ LogGroup }}'"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Software Installation"
    Type    = "Unreal Engine"
  })
}

# SSM Document for Perforce installation
resource "aws_ssm_document" "install_perforce" {
  name          = "${local.name_prefix}-install-perforce"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install Perforce Client Tools (P4, P4V, P4Admin)"
    parameters = {
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "installPerforce"
      inputs = {
        timeoutSeconds = "2400"
        runCommand = [
          "aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/runtime/install-perforce.ps1 C:\\temp\\install-perforce.ps1",
          "PowerShell.exe -ExecutionPolicy Bypass -File C:\\temp\\install-perforce.ps1 -LogGroup '{{ LogGroup }}'"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Software Installation"
    Type    = "Perforce"
  })
}

# SSM Document for DCV Users and Sessions Setup
resource "aws_ssm_document" "setup_dcv_users_sessions" {
  name          = "${local.name_prefix}-setup-dcv-users-sessions"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Create VDI users and shared DCV session - Windows single-session architecture"
    parameters = {
      WorkstationKey = {
        type        = "String"
        description = "Workstation identifier"
      }
      AssignedUser = {
        type        = "String"
        description = "Assigned user name"
      }
      UserSource = {
        type        = "String"
        description = "User source (local or ad)"
        default     = "local"
      }
      ProjectPrefix = {
        type        = "String"
        description = "Project prefix for secrets"
      }
      LogGroup = {
        type        = "String"
        description = "CloudWatch log group for installation logs"
        default     = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "setupDCVUsersAndSessions"
      precondition = {
        StringEquals = ["platformType", "Windows"]
      }
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "# VDI Users and DCV Sessions Setup - Windows Server 2025",
          "$ErrorActionPreference = 'Stop'",
          "$WorkstationKey = '{{ WorkstationKey }}'",
          "$AssignedUser = '{{ AssignedUser }}'",
          "$UserSource = '{{ UserSource }}'",
          "$ProjectPrefix = '{{ ProjectPrefix }}'",
          "",
          "Write-Host \"Starting DCV users and sessions setup for $WorkstationKey...\"",
          "",
          "# Ensure DCV service is running",
          "Write-Host \"Starting DCV service...\"",
          "Start-Service -Name dcvserver -ErrorAction SilentlyContinue",
          "Set-Service -Name dcvserver -StartupType Automatic",
          "Start-Sleep -Seconds 10",
          "",
          "# Create VDIAdmin user using pre-created Secrets Manager password",
          "Write-Host \"Creating VDIAdmin user...\"",
          "try {",
          "    # Get VDIAdmin password from Secrets Manager (same pattern as regular users)",
          "    Import-Module AWS.Tools.SecretsManager -Force",
          "    $VDIAdminSecretName = \"$ProjectPrefix/$WorkstationKey/users/vdiadmin\"",
          "    $VDIAdminSecretValue = Get-SECSecretValue -SecretId $VDIAdminSecretName -Region ${data.aws_region.current.region}",
          "    $VDIAdminData = $VDIAdminSecretValue.SecretString | ConvertFrom-Json",
          "    $SecureVDIAdminPassword = ConvertTo-SecureString $VDIAdminData.password -AsPlainText -Force",
          "    ",
          "    # Create or update VDIAdmin user",
          "    try {",
          "        New-LocalUser -Name 'VDIAdmin' -Password $SecureVDIAdminPassword -FullName 'VDI Administrator' -Description 'VDI Management Account' -ErrorAction Stop",
          "        Write-Host 'Created new VDIAdmin user'",
          "    } catch {",
          "        if ($_.Exception.Message -like '*already exists*') {",
          "            Write-Host 'VDIAdmin user already exists, updating password'",
          "            Set-LocalUser -Name 'VDIAdmin' -Password $SecureVDIAdminPassword",
          "        } else {",
          "            throw $_",
          "        }",
          "    }",
          "    Add-LocalGroupMember -Group 'Administrators' -Member 'VDIAdmin' -ErrorAction SilentlyContinue",
          "    Add-LocalGroupMember -Group 'Remote Desktop Users' -Member 'VDIAdmin' -ErrorAction SilentlyContinue",
          "    ",
          "    Write-Host \"VDIAdmin user created using Secrets Manager password\"",
          "} catch {",
          "    Write-Warning \"VDIAdmin creation failed: $_\"",
          "}",
          "",
          "# Create local user if user source is local",
          "if ($UserSource -eq 'local') {",
          "    Write-Host \"Ensuring local user $AssignedUser exists...\"",
          "    try {",
          "        Get-LocalUser -Name $AssignedUser -ErrorAction Stop",
          "        Write-Host \"User $AssignedUser already exists\"",
          "    } catch {",
          "        Write-Host \"Creating local user $AssignedUser...\"",
          "        try {",
          "            # Get password from Secrets Manager",
          "            Import-Module AWS.Tools.SecretsManager -Force",
          "            $UserSecretName = \"$ProjectPrefix/$WorkstationKey/users/$AssignedUser\"",
          "            $UserSecretValue = Get-SECSecretValue -SecretId $UserSecretName -Region ${data.aws_region.current.region}",
          "            $UserData = $UserSecretValue.SecretString | ConvertFrom-Json",
          "            $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force",
          "            ",
          "            # Create the user",
          "            New-LocalUser -Name $AssignedUser -Password $UserPassword -FullName \"$($UserData.given_name) $($UserData.family_name)\" -Description \"VDI User\" -ErrorAction Stop",
          "            Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $AssignedUser -ErrorAction SilentlyContinue",
          "            Write-Host \"Successfully created user $AssignedUser\"",
          "        } catch {",
          "            Write-Warning \"Failed to create user $AssignedUser`: $_\"",
          "        }",
          "    }",
          "}",
          "",
          "# Create DCV sessions",
          "Write-Host \"Creating DCV sessions...\"",
          "$dcvPath = 'C:\\Program Files\\NICE\\DCV\\Server\\bin\\dcv.exe'",
          "",
          "# Aggressively close any existing sessions to free up slots",
          "Write-Host \"Closing all existing sessions...\"",
          "$existingSessions = & $dcvPath list-sessions 2>$null | Select-String \"Session:\" | ForEach-Object { ($_ -split \"'\")[1] }",
          "foreach ($session in $existingSessions) {",
          "    Write-Host \"Closing session: $session\"",
          "    & $dcvPath close-session $session 2>$null",
          "}",
          "Start-Sleep -Seconds 5",
          "",
          "# Function to create DCV session safely",
          "function New-DCVSession {",
          "    param([string]$Owner, [string]$SessionName)",
          "    try {",
          "        & $dcvPath create-session --owner $Owner $SessionName 2>$null",
          "        if ($LASTEXITCODE -eq 0) {",
          "            Write-Host \"Created DCV session: $SessionName (owner: $Owner)\"",
          "            return $true",
          "        } else {",
          "            Write-Warning \"Failed to create session $SessionName for $Owner\"",
          "            return $false",
          "        }",
          "    } catch {",
          "        Write-Warning \"Exception creating session $SessionName`: $_\"",
          "        return $false",
          "    }",
          "}",
          "",
          "# Create single shared DCV session owned by assigned user",
          "# Admins can join this session, or use RDP for independent access",
          "if ($UserSource -eq 'local') {",
          "    Write-Host \"Creating shared DCV session for $AssignedUser...\"",
          "    New-DCVSession -Owner $AssignedUser -SessionName \"$AssignedUser-session\"",
          "    ",
          "    # Configure session sharing permissions",
          "    Write-Host \"Configuring session sharing permissions...\"",
          "    $permissionsContent = \"[permissions]`n%any% allow connect-session`nAdministrator allow builtin`nVDIAdmin allow builtin`n$AssignedUser allow builtin\"",
          "    $permissionsContent | Out-File -FilePath 'C:\\Program Files\\NICE\\DCV\\Server\\conf\\default.pv' -Encoding ASCII -Force",
          "    ",
          "    # Restart DCV to apply permissions",
          "    Restart-Service dcvserver -Force",
          "    Start-Sleep -Seconds 10",
          "    ",
          "    # Recreate session after restart",
          "    New-DCVSession -Owner $AssignedUser -SessionName \"$AssignedUser-session\"",
          "} else {",
          "    Write-Host \"AD user session creation will be handled after domain join\"",
          "}",
          "",
          "# List all sessions for verification",
          "Write-Host \"Current DCV sessions:\"",
          "& $dcvPath list-sessions",
          "",
          "Write-Host \"DCV users and sessions setup completed successfully\""
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "VDI User Management"
    Type    = "DCV Setup"
  })
}

# Software package mapping
locals {
  software_package_mapping = {
    "chocolatey"         = aws_ssm_document.setup_chocolatey.name
    "visual-studio-2022" = aws_ssm_document.install_visual_studio.name
    "git"               = aws_ssm_document.install_git.name
    "unreal-engine-5.3" = aws_ssm_document.install_unreal_engine.name
    "perforce"          = aws_ssm_document.install_perforce.name
  }
}

# SSM Association for DCV Users and Sessions Setup (Priority 1 - Critical)
resource "aws_ssm_association" "dcv_setup" {
  for_each = var.workstation_assignments

  name = aws_ssm_document.setup_dcv_users_sessions.name
  
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    WorkstationKey = each.key
    AssignedUser   = each.value.user
    UserSource     = each.value.user_source
    ProjectPrefix  = var.project_prefix
    LogGroup       = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [
    aws_instance.workstations,
    aws_secretsmanager_secret_version.user_passwords
  ]

  tags = merge(var.tags, {
    Assignment = each.key
    Purpose    = "DCV Setup"
    Priority   = "Critical"
  })
}

# Associations provide reliable execution - manual trigger available for speed

# Immediate software installation via send-command
# Software installation via associations (reliable execution)
resource "aws_ssm_association" "install_chocolatey" {
  for_each = local.chocolatey_workstations

  name = aws_ssm_document.setup_chocolatey.name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [aws_instance.workstations, aws_ssm_association.dcv_setup]

  tags = merge(var.tags, {
    Assignment = each.key
    Package = "chocolatey"
    Purpose = "Software Installation"
  })
}

resource "aws_ssm_association" "install_git" {
  for_each = local.git_workstations

  name = aws_ssm_document.install_git.name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [aws_instance.workstations, aws_ssm_association.dcv_setup]

  tags = merge(var.tags, {
    Assignment = each.key
    Package = "git"
    Purpose = "Software Installation"
  })
}

resource "aws_ssm_association" "install_visual_studio" {
  for_each = local.visual_studio_workstations

  name = aws_ssm_document.install_visual_studio.name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [aws_instance.workstations, aws_ssm_association.dcv_setup]

  tags = merge(var.tags, {
    Assignment = each.key
    Package = "visual-studio-2022"
    Purpose = "Software Installation"
  })
}

resource "aws_ssm_association" "install_unreal_engine" {
  for_each = local.unreal_engine_workstations

  name = aws_ssm_document.install_unreal_engine.name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [aws_instance.workstations, aws_ssm_association.dcv_setup]

  tags = merge(var.tags, {
    Assignment = each.key
    Package = "unreal-engine-5.3"
    Purpose = "Software Installation"
  })
}

resource "aws_ssm_association" "install_perforce" {
  for_each = local.perforce_workstations

  name = aws_ssm_document.install_perforce.name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [aws_instance.workstations, aws_ssm_association.dcv_setup]

  tags = merge(var.tags, {
    Assignment = each.key
    Package = "perforce"
    Purpose = "Software Installation"
  })
}

# SSM Document for custom scripts
resource "aws_ssm_document" "run_custom_script" {
  name = "${local.name_prefix}-run-custom-script"
  document_type = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description = "Run custom PowerShell script"
    parameters = {
      ScriptSource = {
        type = "String"
        description = "S3 URL or script name"
      }
      LogGroup = {
        type = "String"
        description = "CloudWatch log group for script logs"
        default = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
      }
    }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name = "runCustomScript"
      inputs = {
        timeoutSeconds = "3600"
        runCommand = [
          "# Download and run custom script",
          "$ScriptSource = '{{ ScriptSource }}'",
          "if ($ScriptSource.StartsWith('s3://')) {",
          "    # Direct S3 URL",
          "    $LocalPath = \"C:\\temp\\$(Split-Path $ScriptSource -Leaf)\"",
          "    aws s3 cp $ScriptSource $LocalPath",
          "} else {",
          "    # Script name from module bucket", 
          "    $LocalPath = \"C:\\temp\\$ScriptSource\"",
          "    aws s3 cp s3://${aws_s3_bucket.scripts.id}/scripts/custom/$ScriptSource $LocalPath",
          "}",
          "PowerShell.exe -ExecutionPolicy Bypass -File $LocalPath"
        ]
      }
    }]
  })

  tags = merge(var.tags, {
    Purpose = "Custom Script Execution"
    Type = "Custom Script"
  })
}

# SSM Associations for custom scripts
resource "aws_ssm_association" "custom_scripts" {
  for_each = local.custom_script_associations

  name = aws_ssm_document.run_custom_script.name
  
  targets {
    key = "InstanceIds"
    values = [aws_instance.workstations[each.value.assignment_key].id]
  }

  parameters = {
    ScriptSource = each.value.is_s3 ? each.value.script_path : each.value.script_name
    LogGroup = var.enable_centralized_logging ? aws_cloudwatch_log_group.vdi_logs[0].name : "/aws/ssm/run-command"
  }

  depends_on = [
    aws_instance.workstations,
    aws_ssm_association.dcv_setup,
    aws_s3_object.custom_scripts
  ]

  tags = merge(var.tags, {
    Assignment = each.value.assignment_key
    Script = each.value.script_name
    Purpose = "Custom Script Execution"
  })
}