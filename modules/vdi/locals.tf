# Local variables for the VDI module
locals {
  # Use either the provided AMI ID or the discovered AMI ID
  ami_id = var.ami_id != null ? var.ami_id : (length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].id : null)

  # Determine which password to use based on AD configuration
  effective_password = local.enable_domain_join ? (
    var.ad_admin_password != "" ? var.ad_admin_password : var.admin_password
  ) : var.admin_password

  # PowerShell script to set administrator password
  user_data_script = local.effective_password != null ? "write-host 'Setting admin password'; $admin = [adsi]('WinNT://./administrator, user'); $admin.psbase.invoke('SetPassword', '${local.effective_password}')" : null

  # Base64 encode the PowerShell script for EC2 user data
  encoded_user_data = local.user_data_script != null ? base64encode("<powershell>${local.user_data_script}</powershell>") : var.user_data_base64

  # AD domain joining configuration
  enable_domain_join = var.directory_id != null
  ssm_document_name  = local.enable_domain_join ? coalesce(var.ssm_document_name, "${var.project_prefix}-${var.name}-domain-join") : null

  # Validation locals
  validate_ad_config = var.directory_id != null ? (
    var.directory_name != null &&
    length(var.dns_ip_addresses) >= 1
  ) : true

  # Validate that at least one password is provided
  validate_password = var.admin_password != "" || var.ad_admin_password != ""
}

# Validation resources
resource "null_resource" "validate_ad_config" {
  count = local.validate_ad_config ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: When directory_id is provided, directory_name and dns_ip_addresses must also be provided' && exit 1"
  }
}

resource "null_resource" "validate_password" {
  count = local.validate_password ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: Either admin_password or ad_admin_password must be provided' && exit 1"
  }
}