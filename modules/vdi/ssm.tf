# Simple SSM solution using file() function to avoid variable escaping issues

# User creation document
resource "aws_ssm_document" "create_vdi_users" {
  name            = "${local.name_prefix}-create-vdi-users"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Creates local Windows users and configures DCV"
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
      ForceRun = {
        type        = "String"
        description = "Force execution trigger"
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
            "powershell.exe -ExecutionPolicy Unrestricted -File 'C:\\temp\\vdi-script.ps1' -WorkstationKey '{{ WorkstationKey }}' -AssignedUser '{{ AssignedUser }}' -ProjectPrefix '{{ ProjectPrefix }}' -Region '{{ Region }}' -ForceRun '{{ ForceRun }}'"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

# Volume initialization document
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
      ForceRun = {
        type        = "String"
        description = "Force execution trigger"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "initializeVolumes"
        inputs = {
          timeoutSeconds = "900"
          runCommand = split("\n", file("${path.module}/assets/scripts/initialize-volumes.ps1"))
        }
      }
    ]
  })

  tags = var.tags
}

# Software installation document (optional background installation)
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
      ForceRun = {
        type        = "String"
        description = "Force execution trigger"
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

# Wait for SSM agent to be fully ready (predictable timing for critical user creation)
resource "time_sleep" "wait_for_ssm_agent" {
  for_each = var.workstations

  depends_on      = [aws_instance.workstations]
  create_duration = "180s" # 3 minutes - reduced from 5 minutes
}

# User creation association (critical path)
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

  parameters = {
    WorkstationKey = each.key
    AssignedUser   = each.value.assigned_user
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    ForceRun       = var.debug ? timestamp() : "false"
  }
}

# Volume initialization association (runs in parallel)
resource "aws_ssm_association" "volume_initialization" {
  for_each = var.workstations

  depends_on = [time_sleep.wait_for_ssm_agent]

  name             = aws_ssm_document.initialize_volumes.name
  association_name = "vdi-volumes-${each.key}"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  parameters = {
    WorkstationKey = each.key
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    VolumeHash     = md5(jsonencode(each.value.volumes))
    ForceRun       = var.debug ? timestamp() : "false"
  }
}

# Software installation (runs after user creation)
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

  parameters = {
    WorkstationKey = each.key
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    SoftwareList   = join(",", local.processed_workstations[each.key].software_packages)
    ForceRun       = var.debug ? timestamp() : "false"
  }
}


