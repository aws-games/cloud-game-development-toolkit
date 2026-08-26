##################################################
# FSx for NetApp ONTAP - Admin Credentials
##################################################

# Generate the fsxadmin password used to manage the ONTAP file system. The
# BuildGraph tasks (SyncAndSnapshot / CloneVolume / DeleteVolume) retrieve this
# secret at runtime to call the ONTAP REST API.
resource "random_password" "fsxn_admin" {
  length  = 24
  special = true
  # ONTAP rejects some special characters in the admin password; keep to a
  # safe, widely-accepted set.
  override_special = "!#$%&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "fsxn_admin" {
  name        = "${local.name_prefix}-fsxn-fsxadmin"
  description = "fsxadmin password for the FSx for ONTAP file system used by the Horde build pipeline."

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-fsxn-fsxadmin"
  })

  #checkov:skip=CKV2_AWS_57: Automatic rotation is out of scope for this sample
}

resource "aws_secretsmanager_secret_version" "fsxn_admin" {
  secret_id     = aws_secretsmanager_secret.fsxn_admin.id
  secret_string = random_password.fsxn_admin.result
}

##################################################
# FSx for NetApp ONTAP - File System
##################################################

resource "aws_fsx_ontap_file_system" "workspace" {
  storage_capacity    = var.fsxn_storage_capacity_gb
  throughput_capacity = var.fsxn_throughput_capacity
  deployment_type     = "SINGLE_AZ_1"

  # Single-AZ deployment lives in a single private service subnet.
  subnet_ids          = [aws_subnet.private_svc_subnets[0].id]
  preferred_subnet_id = aws_subnet.private_svc_subnets[0].id

  storage_type       = "SSD"
  fsx_admin_password = random_password.fsxn_admin.result

  # Security group created in security.tf (JT-08). NFSv3 (2049/111) and the
  # ONTAP REST API (443) are permitted only from the Horde agent SG.
  security_group_ids = [aws_security_group.fsxn.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-fsxn"
  })
}

##################################################
# FSx for NetApp ONTAP - Storage Virtual Machine (NFS only, no CIFS/AD)
##################################################

resource "aws_fsx_ontap_storage_virtual_machine" "workspace" {
  file_system_id = aws_fsx_ontap_file_system.workspace.id
  name           = local.fsxn_svm_name

  # NFS-only workspace SVM: no active_directory_configuration block is set,
  # so no CIFS/AD is provisioned.

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-svm"
  })
}

##################################################
# FSx for NetApp ONTAP - Source Volume
#
# AWS-native aws_fsx_ontap_volume resource is used for the persistent source
# volume (Option 1, approved by the user) to dissolve the netapp-ontap provider
# chicken-and-egg. FlexClones and snapshots are created at runtime via the
# ONTAP REST API from BuildGraph tasks - not by Terraform.
##################################################

resource "aws_fsx_ontap_volume" "source" {
  name                       = local.fsxn_source_volume_name
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.workspace.id

  junction_path              = local.fsxn_source_junction_path
  security_style             = "UNIX"
  size_in_megabytes          = var.fsxn_storage_capacity_gb * 1024
  storage_efficiency_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-source-volume"
  })
}

##################################################
# netapp-ontap Provider (placeholder)
#
# The perforce module declares netapp-ontap as a REQUIRED provider (for its
# FSxN storage path). This sample does not use the provider from Terraform:
# the source volume is created with the AWS-native resource above, and all
# FlexClone / snapshot operations happen at runtime via the ONTAP REST API in
# the BuildGraph tasks. This placeholder block satisfies the provider
# requirement without connecting to a live ONTAP cluster.
##################################################

provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "null"
      hostname = "null"
      username = "null"
      password = "null"
    }
  ]
}
