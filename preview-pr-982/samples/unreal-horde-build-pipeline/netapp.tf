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

  # Security group created in security.tf. iSCSI (3260) and the ONTAP REST API
  # (443) are permitted only from the Horde agent SG.
  security_group_ids = [aws_security_group.fsxn.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-fsxn"
  })
}

##################################################
# FSx for NetApp ONTAP - Storage Virtual Machine (SAN/iSCSI, no CIFS/AD)
#
# No active_directory_configuration block, so no CIFS/AD is provisioned. That is
# still correct on the SAN path: iSCSI authorises by initiator IQN (igroups), not
# by a directory identity, so NTFS-on-a-LUN needs no AD at all. This is why iSCSI
# gives real NTFS semantics WITHOUT the AD dependency that SMB would impose - the
# trade-off ADR-002 assumed it had to make.
##################################################

resource "aws_fsx_ontap_storage_virtual_machine" "workspace" {
  file_system_id = aws_fsx_ontap_file_system.workspace.id
  name           = local.fsxn_svm_name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-svm"
  })
}

##################################################
# FSx for NetApp ONTAP - Source Volume (SAN container for the workspace LUN)
#
# This volume is a CONTAINER. The thing agents actually mount is a thin LUN
# inside it (/vol/<volume>/<lun>), created at runtime - the AWS provider cannot
# create LUNs, igroups or LUN maps, so hydrate-source-lun.ps1 does it through the
# ONTAP REST API (create-if-absent). FlexClones and snapshots are likewise
# runtime operations, not Terraform ones.
#
# Sized larger than the LUN on purpose: the LUN is thin-provisioned with
# space-allocation enabled, and the container needs headroom for snapshot deltas.
# Every snapshot the hydrator keeps costs the blocks changed since the previous
# one, so a volume sized equal to the LUN will start failing snapshot creation.
##################################################

resource "aws_fsx_ontap_volume" "source" {
  name                       = local.fsxn_source_volume_name
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.workspace.id

  # FSx REQUIRES a junction path even for a volume that will only ever serve a
  # LUN - CreateVolume rejects the request without one. It is unused on the SAN
  # path: nothing NFS-mounts this volume.
  junction_path = local.fsxn_source_junction_path

  # UNIX rather than NTFS security style, deliberately. NTFS style would demand an
  # AD-joined SVM, and it buys nothing here: the LUN's own NTFS filesystem governs
  # file permissions, and the volume's style only affects NAS access, which is not
  # used.
  security_style = "UNIX"

  size_in_megabytes          = var.fsxn_san_volume_size_gb * 1024
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
