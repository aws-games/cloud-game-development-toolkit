# Simple SSM solution using file() function to avoid variable escaping issues

resource "aws_ssm_document" "create_vdi_users" {
  name          = "${local.name_prefix}-create-vdi-users"
  document_type = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Creates local Windows users from Terraform-generated passwords in Secrets Manager"
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
        description = "Force execution trigger (debug mode)"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "writeScript"
        inputs = {
          runCommand = [
            "New-Item -ItemType Directory -Path 'C:\\temp' -Force",
            "Set-Content -Path 'C:\\temp\\vdi-script.ps1' -Value @'\n${file("${path.module}/create-vdi-users-simple.ps1")}\n'@"
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

# Wait for SSM agent to be fully ready
resource "time_sleep" "wait_for_ssm_agent" {
  for_each = var.workstation_assignments
  
  depends_on = [aws_instance.workstations]
  create_duration = "300s"  # 5 minutes - ensures SSM agent is ready
}

# SSM association with guaranteed timing
resource "aws_ssm_association" "vdi_user_creation" {
  for_each = var.workstation_assignments
  
  depends_on = [time_sleep.wait_for_ssm_agent]
  
  name = aws_ssm_document.create_vdi_users.name
  association_name = "vdi-setup-${aws_instance.workstations[each.key].id}"
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }
  
  parameters = {
    WorkstationKey = each.key
    AssignedUser   = each.value.user
    ProjectPrefix  = var.project_prefix
    Region         = var.region
    ForceRun       = var.debug_mode ? timestamp() : "disabled"
  }
}