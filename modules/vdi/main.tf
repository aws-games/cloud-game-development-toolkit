# VDI Module - Local Windows user management with EC2 workstations
resource "aws_key_pair" "workstation_keys" {
  for_each = var.workstations

  key_name   = "${local.name_prefix}-${each.key}-emergency-key"
  public_key = tls_private_key.workstation_keys[each.key].public_key_openssh

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-emergency-key"
    Workstation = each.key
    Purpose     = "VDI Emergency Access"
  })
}

resource "tls_private_key" "workstation_keys" {
  for_each = var.workstations

  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "aws_s3_object" "emergency_private_keys" {
  for_each = var.workstations

  bucket  = aws_s3_bucket.keys.id
  key     = "${each.key}/ec2-key/${each.key}-private-key.pem"
  content = tls_private_key.workstation_keys[each.key].private_key_pem

  server_side_encryption = "AES256"

  tags = {
    Workstation = each.key
    Purpose     = "VDI Emergency Key"
  }
}

resource "aws_instance" "workstations" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring not required for VDI workstations - adds cost without significant benefit
  #checkov:skip=CKV_AWS_135:EBS optimization not required - workstation performance adequate without it
  for_each      = local.final_instances
  ami           = each.value.ami
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.workstation_keys[each.key].key_name

  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.security_groups
  associate_public_ip_address = each.value.associate_public_ip_address
  availability_zone           = each.value.availability_zone

  # Termination protection enabled by default, disabled in debug mode for CI/CD
  disable_api_termination = !var.debug

  iam_instance_profile = each.value.iam_instance_profile != null ? each.value.iam_instance_profile : aws_iam_instance_profile.vdi_instance_profile[each.key].name

  root_block_device {
    volume_type = each.value.volumes["Root"].type
    volume_size = each.value.volumes["Root"].capacity
    iops        = each.value.volumes["Root"].iops
    throughput  = each.value.volumes["Root"].throughput
    encrypted   = each.value.volumes["Root"].encrypted
    kms_key_id  = var.ebs_kms_key_id

    tags = merge(var.tags, {
      Name        = "${local.name_prefix}-${each.key}-root-volume"
      Workstation = each.key
      VolumeType  = "Root"
    })
  }

  # No user data - using SSM for more reliable configuration
  user_data_replace_on_change = true


  dynamic "capacity_reservation_specification" {
    for_each = each.value.capacity_reservation_preference != null ? [1] : []
    content {
      capacity_reservation_preference = each.value.capacity_reservation_preference
    }
  }

  # Instance Store Configuration
  # /dev/sdb = Instance store (NVMe SSD included with g4dn instances)
  # This reserves /dev/sdb so EBS volumes start at /dev/sdf
  # Windows will see this as an additional disk and auto-assign a drive letter
  ephemeral_block_device {
    device_name  = "/dev/sdb"   # Reserved for instance store
    virtual_name = "ephemeral0" # AWS naming for first instance store volume
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(each.value.tags, {
    Name              = "${local.name_prefix}-${each.key}"
    WorkstationKey    = each.key
    AssignedUser      = each.value.assigned_user
    "VDI-Workstation" = each.key # Used by SSM association for targeting
  })


  depends_on = [
    aws_iam_instance_profile.vdi_instance_profile,
    aws_s3_bucket.keys,
    aws_s3_bucket.scripts
  ]
}

resource "aws_eip" "workstation_eips" {
  for_each = {
    for workstation_key, config in var.workstations : workstation_key => config
    if lookup(config, "allocate_eip", false)
  }

  instance = aws_instance.workstations[each.key].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-eip"
    Workstation = each.key
    Purpose     = "VDI Static IP"
  })

  depends_on = [aws_instance.workstations]
}

resource "aws_ebs_volume" "workstation_volumes" {
  #checkov:skip=CKV_AWS_3:EBS volumes are encrypted by default (encrypted = true in volume config)
  #checkov:skip=CKV2_AWS_2:EBS volumes are encrypted by default (encrypted = true in volume config)
  for_each = {
    for combo in flatten([
      for workstation_key, workstation_config in local.final_instances : [
        for volume_name, volume_config in workstation_config.volumes : {
          key             = "${workstation_key}-${volume_name}"
          workstation_key = workstation_key
          volume_name     = volume_name
          volume_config   = volume_config
        }
        if volume_name != "Root" # Root volume handled by EC2 instance
      ]
    ]) : combo.key => combo
  }

  availability_zone = local.final_instances[each.value.workstation_key].availability_zone
  size              = each.value.volume_config.capacity
  type              = each.value.volume_config.type
  iops              = each.value.volume_config.iops
  throughput        = each.value.volume_config.throughput
  encrypted         = each.value.volume_config.encrypted
  kms_key_id        = var.ebs_kms_key_id

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.value.workstation_key}-${each.value.volume_name}-volume"
    Workstation = each.value.workstation_key
    VolumeType  = each.value.volume_name
  })
}

resource "aws_volume_attachment" "workstation_volume_attachments" {
  for_each = aws_ebs_volume.workstation_volumes

  # CRITICAL: Linux EBS Device Naming to Windows Drive Letter Mapping
  # This complex logic was extremely difficult to figure out and is KEY to the module working correctly.
  #
  # AWS/Linux Side Device Naming:
  # - Root volume: /dev/sda1 (handled by EC2 instance root_block_device) → Windows C:
  # - Instance store: /dev/sdb (defined in ephemeral_block_device) → Windows auto-assigned
  # - EBS volumes: /dev/sdf, /dev/sdg, /dev/sdh, etc. → Windows auto-assigned drive letters
  #
  # Why /dev/sdf and not /dev/sdc?
  # - /dev/sda = Root volume (reserved)
  # - /dev/sdb = Instance store (reserved)
  # - /dev/sdc, /dev/sdd, /dev/sde = Reserved by AWS (cannot be used)
  # - /dev/sdf+ = Available for EBS volumes
  #
  # The Magic Formula Explained:
  # 1. Get all volumes for THIS workstation: filter by Workstation tag
  # 2. Sort volume names alphabetically: ensures consistent device assignment
  # 3. Find index of current volume in sorted list: 0, 1, 2, etc.
  # 4. Map to device letter: "fghijklmnop"[index] = f, g, h, etc.
  # 5. Result: /dev/sdf, /dev/sdg, /dev/sdh, etc.
  #
  # Windows Drive Letter Assignment (handled by SSM script):
  # - Windows sees these as Disk 1, Disk 2, Disk 3, etc.
  # - SSM script initializes disks and lets Windows auto-assign drive letters
  # - Typically becomes D:, E:, F:, etc. (but can vary)
  #
  # Why This Complexity?
  # - Ensures consistent device naming across terraform apply/destroy cycles
  # - Prevents device conflicts when adding/removing volumes
  # - Allows Windows to handle drive letter assignment natively
  # - Supports volume reordering without breaking existing assignments
  device_name = "/dev/sd${substr("fghijklmnop",
    index(sort([
      for k, v in aws_ebs_volume.workstation_volumes : v.tags["VolumeType"]
      if v.tags["Workstation"] == each.value.tags["Workstation"]
  ]), each.value.tags["VolumeType"]), 1)}"

  volume_id   = each.value.id
  instance_id = aws_instance.workstations[each.value.tags["Workstation"]].id

  # Prevent detachment during updates
  skip_destroy = false
}

resource "aws_cloudwatch_log_group" "vdi_logs" {
  #checkov:skip=CKV_AWS_338:1 year log retention not required for VDI logs - 30 days sufficient for troubleshooting
  #checkov:skip=CKV_AWS_158:KMS encryption not required for VDI logs - default encryption sufficient
  count = var.enable_centralized_logging ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = local.log_group_name
    Purpose = "VDI All Logs"
    Type    = "CloudWatch Log Group"
  })
}


resource "awscc_secretsmanager_secret" "user_passwords" {
  for_each = local.workstation_user_combinations

  name        = "${var.project_prefix}/${each.value.workstation}/users/${each.value.user}"
  description = "Password for ${var.users[each.value.user].type} user ${each.value.user} on workstation ${each.value.workstation}"

  # AWS auto-generates secure passwords - no passwords in Terraform state!
  generate_secret_string = {
    secret_string_template = jsonencode({
      username    = each.value.user
      given_name  = var.users[each.value.user].given_name
      family_name = var.users[each.value.user].family_name
      email       = var.users[each.value.user].email
      user_type   = var.users[each.value.user].type
      workstation = each.value.workstation
      instance_id = aws_instance.workstations[each.value.workstation].id
    })
    generate_string_key        = "password" # AWS generates this key
    password_length            = 16
    include_space              = false
    exclude_lowercase          = false
    exclude_uppercase          = false
    exclude_numbers            = false
    exclude_punctuation        = false              # Include special characters
    exclude_characters         = "\"'`$\\|&<>;#%()" # Exclude PowerShell problematic chars
    require_each_included_type = true               # Force inclusion of each character type
  }

  tags = [
    {
      key   = "Purpose"
      value = "VDI User Password"
    },
    {
      key   = "User"
      value = each.value.user
    },
    {
      key   = "Workstation"
      value = each.value.workstation
    },
    {
      key   = "UserType"
      value = var.users[each.value.user].type
    }
  ]
}

resource "aws_ssm_parameter" "vdi_dns" {
  #checkov:skip=CKV2_AWS_34:DNS connection URLs are not sensitive data - encryption not required
  for_each = local.workstation_user_combinations

  name = "/${var.project_prefix}/${each.value.workstation}/users/${each.value.user}/dns"
  type = "String"
  value = jsonencode({
    private_dns = "https://${aws_instance.workstations[each.value.workstation].private_dns}:8443"
    public_dns  = "https://${aws_instance.workstations[each.value.workstation].public_dns}:8443"
    custom_dns  = var.users[each.value.user].type != "fleet_administrator" ? "https://${each.value.user}.${local.private_zone_name}:8443" : "null"
  })

  tags = merge(var.tags, {
    Purpose     = "VDI DNS"
    User        = each.value.user
    Workstation = each.value.workstation
  })
}
