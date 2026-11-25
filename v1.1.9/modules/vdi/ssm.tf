# SSM solution using file() function to avoid variable escaping issues
#
# CRITICAL SSM RE-EXECUTION BEHAVIOR (per AWS Support):
# - Parameter changes do NOT trigger re-execution
# - Only these trigger re-execution: Document content changes, Association recreation, Manual execution
# - Previous ForceRun parameter worked because timestamp() changed the PowerShell command line,
#   which changed document content, which triggered re-execution
# - Now we use lifecycle rules to recreate associations when infrastructure actually changes
resource "aws_ssm_document" "create_vdi_users" {
  name            = "${local.name_prefix}-create-vdi-users"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Creates local Windows users and configures DCV"
    # Parameters are data passed from Terraform → SSM → PowerShell script arguments
    # Changing parameter VALUES does not trigger re-execution (AWS Support confirmed)
    # Only document content changes or association recreation triggers execution
    parameters = {
      WorkstationKey = {
        type        = "String"
        description = "Workstation identifier"
      }
      AssignedUser = {
        type        = "String"
        description = "Primary assigned user"
      }
      ProjectPrefix = {
        type        = "String"
        description = "Project prefix for secrets"
      }
      Region = {
        type        = "String"
        description = "AWS region"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "writeScript"
        inputs = {
          runCommand = [
            "New-Item -ItemType Directory -Path 'C:\\temp' -Force",
            "Set-Content -Path 'C:\\temp\\vdi-script.ps1' -Value @'\n${file("${path.module}/assets/scripts/create-vdi-users.ps1")}\n'@"
          ]
        }
      },
      {
        action = "aws:runPowerShellScript"
        name   = "executeScript"
        inputs = {
          timeoutSeconds = "600"
          runCommand = [
            "powershell.exe -ExecutionPolicy Unrestricted -File 'C:\\temp\\vdi-script.ps1' -WorkstationKey '{{ WorkstationKey }}' -AssignedUser '{{ AssignedUser }}' -ProjectPrefix '{{ ProjectPrefix }}' -Region '{{ Region }}'"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_ssm_document" "initialize_volumes" {
  name            = "${local.name_prefix}-initialize-volumes"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Initialize and format EBS volumes"
    parameters = {
      WorkstationKey = {
        type        = "String"
        description = "Workstation identifier"
      }
      ProjectPrefix = {
        type        = "String"
        description = "Project prefix"
      }
      Region = {
        type        = "String"
        description = "AWS region"
      }
      VolumeHash = {
        type        = "String"
        description = "Hash of volume configuration"
      }
      VolumeMapping = {
        type        = "String"
        description = "JSON mapping of volume sizes to names"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "writeScript"
        inputs = {
          runCommand = [
            "New-Item -ItemType Directory -Path 'C:\\temp' -Force",
            "Set-Content -Path 'C:\\temp\\vdi-volume-script.ps1' -Value @'\n${file("${path.module}/assets/scripts/initialize-volumes.ps1")}\n'@"
          ]
        }
      },
      {
        action = "aws:runPowerShellScript"
        name   = "executeScript"
        inputs = {
          timeoutSeconds = "900"
          runCommand = [
            "powershell.exe -ExecutionPolicy Unrestricted -File 'C:\\temp\\vdi-volume-script.ps1' -WorkstationKey '{{ WorkstationKey }}' -ProjectPrefix '{{ ProjectPrefix }}' -Region '{{ Region }}' -VolumeHash '{{ VolumeHash }}' -VolumeMapping '{{ VolumeMapping }}'"
          ]
        }

      }
    ]
  })

  tags = var.tags
}

resource "aws_ssm_document" "install_software" {
  count = length([
    for workstation_key, config in local.processed_workstations :
    workstation_key if config.software_packages != null
  ]) > 0 ? 1 : 0

  name            = "${local.name_prefix}-install-software"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install software packages using Chocolatey (background process)"
    parameters = {
      WorkstationKey = {
        type        = "String"
        description = "Workstation identifier"
      }
      ProjectPrefix = {
        type        = "String"
        description = "Project prefix"
      }
      Region = {
        type        = "String"
        description = "AWS region"
      }
      SoftwareList = {
        type        = "String"
        description = "Comma-separated list of Chocolatey packages"
      }

    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "installSoftware"
        inputs = {
          timeoutSeconds = "3600" # 1 hour timeout for software installation
          runCommand = [
            "Write-Host 'Starting software installation for workstation {{ WorkstationKey }}'",
            "$packages = '{{ SoftwareList }}' -split ','",
            "$failedPackages = @()",
            "$installedCount = 0",
            "foreach ($package in $packages) {",
            "  Write-Host \"Installing package: $package\"",
            "  try {",
            "    choco install $package -y --ignore-checksums",
            "    Write-Host \"Successfully installed: $package\"",
            "    $installedCount++",
            "  } catch {",
            "    Write-Host \"Failed to install $package : $_\" -ForegroundColor Yellow",
            "    $failedPackages += $package",
            "  }",
            "}",
            "if ($failedPackages.Count -eq 0) {",
            "  Write-Host \"All $($packages.Count) packages installed successfully\"",
            "} else {",
            "  Write-Host \"Software install failed: $($failedPackages.Count) packages failed ($($failedPackages -join ', ')). Check Chocolatey logs.\" -ForegroundColor Red",
            "}",
            "Write-Host 'Software installation completed'"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

# CRITICAL: Wait for SSM Agent to be ready before creating associations
#
# Why this wait is necessary:
# - SSM associations run immediately after creation (AWS default behavior)
# - Windows instances need time to boot and start SSM Agent service
# - If associations are created before SSM Agent is ready, they attempt to run and fail
# - SSM retry intervals are undefined and unreliable (could be minutes or hours)
# - This wait ensures deterministic, reliable automation on first deployment
#
# Without this wait:
# - Association created → Tries to run immediately → Instance not ready → Waits for unknown "next interval"
# - Results in non-deterministic behavior and potential automation failures
#
# With this wait:
# - Association created → Instance guaranteed ready → Runs successfully immediately
# - Provides predictable, reliable automation behavior
resource "time_sleep" "wait_for_ssm_agent" {
  for_each = var.workstations

  depends_on      = [aws_instance.workstations]
  create_duration = "180s" # 3 minutes - validated timing for Windows SSM Agent startup
}

resource "aws_ssm_association" "vdi_user_creation" {
  for_each = {
    for workstation_key, config in var.workstations :
    workstation_key => config
    if config.assigned_user != null
  }

  depends_on = [time_sleep.wait_for_ssm_agent]

  name             = aws_ssm_document.create_vdi_users.name
  association_name = "vdi-users-${each.key}"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  # Parameters: Data pipeline from Terraform → SSM → PowerShell script arguments
  # These values are injected into {{ WorkstationKey }}, {{ AssignedUser }}, etc. in the document
  # Parameter changes alone do NOT trigger re-execution - only lifecycle rules do
  parameters = {
    WorkstationKey = each.key
    AssignedUser   = each.value.assigned_user
    ProjectPrefix  = var.project_prefix
    Region         = var.region
  }

  lifecycle {
    # Recreate when user assignments or user definitions change
    # - aws_instance.workstations: Triggers when instances change (assigned_user parameter)
    # - awscc_secretsmanager_secret.user_passwords: Triggers when user definitions change
    replace_triggered_by = [
      aws_instance.workstations,
      awscc_secretsmanager_secret.user_passwords
    ]
  }
}

resource "aws_ssm_association" "volume_initialization" {
  for_each = var.workstations

  depends_on = [aws_volume_attachment.workstation_volume_attachments, time_sleep.wait_for_ssm_agent]

  name             = aws_ssm_document.initialize_volumes.name
  association_name = "vdi-volumes-${each.key}"

  apply_only_at_cron_interval      = false
  wait_for_success_timeout_seconds = 900
  max_concurrency                  = "1"
  max_errors                       = "0"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  # Parameters: Data pipeline from Terraform → SSM → PowerShell script arguments
  # VolumeHash and VolumeMapping are passed to script but don't trigger re-execution
  #
  # CRITICAL: AWS SSM parameter changes do NOT trigger script re-execution!
  # Only these trigger re-execution: Document content changes, Association recreation, Manual execution
  # This is why replace_triggered_by is essential for volume changes to work properly
  parameters = {
    WorkstationKey = each.key
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    VolumeHash     = md5(jsonencode(local.processed_workstations[each.key].volumes))
    VolumeMapping = jsonencode({
      for volume_name, volume_config in local.processed_workstations[each.key].volumes :
      volume_config.device_name => volume_name
      if volume_name != "Root" # Exclude Root volume
    })
  }

  lifecycle {
    # CRITICAL: Both resources needed for complete volume change detection
    # - aws_volume_attachment: Triggers when adding/removing volumes (device mappings change)
    # - aws_ebs_volume: Triggers when resizing existing volumes (capacity/type/iops changes)
    # Without both, volume changes won't trigger script re-execution due to AWS SSM behavior
    replace_triggered_by = [
      aws_volume_attachment.workstation_volume_attachments,
      aws_ebs_volume.workstation_volumes
    ]
  }
}


resource "aws_ssm_association" "software_installation" {
  for_each = {
    for workstation_key, config in var.workstations :
    workstation_key => config
    if config.assigned_user != null && local.processed_workstations[workstation_key].software_packages != null
  }

  depends_on = [aws_ssm_association.vdi_user_creation]

  name             = aws_ssm_document.install_software[0].name
  association_name = "vdi-software-${each.key}"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  # Parameters: Data pipeline from Terraform → SSM → PowerShell script arguments
  # SoftwareList is passed to script but doesn't trigger re-execution
  # Only replace_triggered_by lifecycle rule triggers re-execution when software changes
  parameters = {
    WorkstationKey = each.key
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    SoftwareList   = join(",", local.processed_workstations[each.key].software_packages)
  }

  lifecycle {
    # Recreate when software packages change
    # Software packages can come from presets or workstation overrides, so we need to track both
    # - aws_instance.workstations: Triggers when workstation config changes (software_packages parameter)
    # Note: Preset changes are handled by workstation config changes since presets are merged into workstations
    replace_triggered_by = [
      aws_instance.workstations
    ]
  }
}
