# Uses AMI's smart DCV configuration that auto-detects authentication method

# Pure AWS native domain join - no custom PowerShell needed (only if directory is provided)
resource "aws_ssm_document" "native_domain_join" {
  count         = local.any_ad_join_required ? 1 : 0
  name          = "${var.project_prefix}-native-domain-join"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Pure AWS native domain join - DCV auto-configures"
    parameters = {
      DirectoryId = {
        type        = "String"
        description = "AWS Directory Service ID"
      }
      DirectoryName = {
        type        = "String"
        description = "Directory domain name"
      }
      DirectoryOU = {
        type        = "String"
        description = "Organizational Unit (optional)"
        default     = ""
      }
    }
    mainSteps = [
      {
        # Check if directory ID is provided before attempting domain join
        action = "aws:runShellScript"
        name   = "CheckDirectoryId"
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "if [ -z '{{ DirectoryId }}' ] || [ '{{ DirectoryId }}' = 'null' ]; then",
            "  echo 'Warning: No directory ID provided, skipping domain join'",
            "  exit 0",
            "fi",
            "echo 'Directory ID provided: {{ DirectoryId }}'"
          ]
        }
      },
      {
        # Use AWS native domain join - only if directory ID is valid
        action = "aws:runDocument"
        name   = "JoinDomain"
        inputs = {
          documentType = "SSMDocument"
          documentPath = "AWS-JoinDirectoryServiceDomain"
          documentParameters = {
            directoryId   = "{{ DirectoryId }}"
            directoryName = "{{ DirectoryName }}"
            directoryOU   = "{{ DirectoryOU }}"
          }
        }
        precondition = {
          StringEquals = [
            "platformType",
            "Windows"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-native-domain-join"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSM Association - for all users joining AD (will be created when directory_id becomes available)
resource "aws_ssm_association" "native_domain_join" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.join_ad
  }

  name             = aws_ssm_document.native_domain_join[0].name
  association_name = "${var.project_prefix}-${each.key}-native-domain-join"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vdi_instances[each.key].id]
  }

  max_concurrency = "1"
  max_errors      = "0"

  parameters = {
    DirectoryId   = var.directory_id != "placeholder" ? var.directory_id : "null"
    DirectoryName = var.directory_name
    DirectoryOU   = var.directory_ou != null ? var.directory_ou : ""
  }

  depends_on = [
    aws_instance.vdi_instances,
    time_sleep.wait_for_instance_ready
  ]
}

# Wait time is defined in main.tf to avoid duplication
# resource "time_sleep" "wait_for_instance_ready" is in main.tf