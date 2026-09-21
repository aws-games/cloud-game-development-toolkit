locals {
  private_zone_name = "${var.project_prefix}.vdi.internal"
  random_id         = random_id.suffix.hex
  name_prefix       = "${var.project_prefix}-${var.environment}"
  log_group_name    = "/${var.project_prefix}/vdi/logs"
  s3_bucket_names = {
    keys    = "${var.project_prefix}-vdi-keys-${local.random_id}"
    scripts = "${var.project_prefix}-vdi-scripts-${local.random_id}"
  }

  # ========================================================================
  # DEVICE ASSIGNMENT LOGIC - Why this complexity exists:
  #
  # Problem: AWS requires unique device names (/dev/sdf, /dev/sdg, etc.) for EBS volumes
  # Challenge: Volumes can come from presets AND workstation overrides, need deterministic assignment
  # Solution: Pre-calculate device mappings to avoid conflicts and ensure consistency
  #
  # Example scenario:
  # - Preset has: Root, Projects, Cache volumes
  # - Workstation adds: ExtraStorage volume
  # - Final result: Root=/dev/sda1, Cache=/dev/sdf, ExtraStorage=/dev/sdg, Projects=/dev/sdh
  # - Same config always produces same device names (deterministic)
  # ========================================================================

  # Step 1: Merge preset + workstation volumes per workstation
  # Why: Workstations can inherit volumes from presets AND add their own volumes
  # Result: Complete volume list for each workstation (preset volumes + workstation volumes)
  workstation_merged_volumes = {
    for workstation_key, config in var.workstations : workstation_key => merge(
      # Get volumes from preset (if workstation uses a preset)
      local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].volumes : {},
      # Add/override with workstation-specific volumes
      config.volumes != null ? config.volumes : {}
    )
  }

  # Step 2: Extract and sort non-root volume names for consistent device ordering
  # Why: Root volume always gets /dev/sda1, other volumes need /dev/sdf, /dev/sdg, etc.
  # Why sort: Ensures same volume names always get same device assignments
  workstation_data_volumes = {
    for workstation_key, volumes in local.workstation_merged_volumes : workstation_key =>
    sort([for k in keys(volumes) : k if k != "Root"]) # Exclude Root, sort alphabetically
  }

  # Step 3: Create volume name -> device path mapping for workstations
  # Why: Pre-calculate device assignments to avoid complex inline logic
  # Logic: "fghijklmnop" = available device letters (f=/dev/sdf, g=/dev/sdg, etc.)
  # Result: {"Projects" => "/dev/sdf", "Cache" => "/dev/sdg", "ExtraStorage" => "/dev/sdh"}
  workstation_device_map = {
    for workstation_key, volume_names in local.workstation_data_volumes : workstation_key => {
      for i, volume_name in volume_names : volume_name => "/dev/sd${substr("fghijklmnop", i, 1)}"
    }
  }

  # Step 4: Same logic for preset templates (needed for preset processing)
  # Why: Presets also need device assignments when they're processed independently
  preset_device_map = {
    for preset_key, config in var.presets : preset_key => {
      for i, volume_name in sort([for k in keys(config.volumes) : k if k != "Root"]) :
      volume_name => "/dev/sd${substr("fghijklmnop", i, 1)}"
    }
  }


  processed_templates = {
    for preset_key, config in var.presets : preset_key => {

      ami           = config.ami # AMI must be specified in templates
      instance_type = config.instance_type
      gpu_enabled   = config.gpu_enabled


      volumes = {
        for volume_name, volume_config in config.volumes : volume_name => {
          capacity   = volume_config.capacity
          type       = volume_config.type
          iops       = volume_config.iops
          throughput = volume_config.throughput
          encrypted  = volume_config.encrypted
          # Device assignment: Root volume = /dev/sda1 (AWS requirement), others use pre-calculated mapping
          device_name = volume_name == "Root" ? "/dev/sda1" : local.preset_device_map[preset_key][volume_name]
        }
      }


      iam_instance_profile   = config.iam_instance_profile
      additional_policy_arns = config.additional_policy_arns
      software_packages      = config.software_packages
      tags = merge(var.tags, config.tags, {
        Preset = preset_key
        Type   = "VDI-Preset"
      })
    }
  }

  # STEP 1: Create workstation-to-preset mapping
  # This creates a lookup table: workstation_key => preset_config (or null if no preset)
  # Example: "vdi-001" => { ami = "ami-123", instance_type = "g4dn.xlarge", ... }
  #          "vdi-002" => null (if using direct config)
  workstation_templates = {
    for workstation_key, config in var.workstations :
    workstation_key => config.preset_key != null ? local.processed_templates[config.preset_key] : null
  }

  # STEP 2: Process each workstation with 3-tier override logic
  # Priority: workstation config > template config > module defaults
  # This supports 3 patterns:
  #   1. Pure template: workstation references template, no overrides
  #   2. Template + overrides: workstation references template + adds/overrides specific values
  #   3. Direct config: workstation defines everything directly (template = null)
  processed_workstations = {
    for workstation_key, config in var.workstations : workstation_key => {
      # CORE CONFIGURATION with 3-tier priority
      # coalesce() returns first non-null value from left to right
      # Example: coalesce("ami-workstation", "ami-preset", "ami-default") = "ami-workstation"
      ami           = coalesce(config.ami, local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].ami : null)
      instance_type = coalesce(config.instance_type, local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].instance_type : null)
      gpu_enabled   = coalesce(config.gpu_enabled, local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].gpu_enabled : null, false)

      # VOLUME CONFIGURATION (merge preset + workstation volumes)
      # Workstation volumes override preset volumes by name, preset volumes remain unless overridden
      volumes = {
        for volume_name, volume_config in merge(
          local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].volumes : {},
          config.volumes != null ? config.volumes : {}
          ) : volume_name => merge(volume_config, {
            # Device assignment: Root volume = /dev/sda1 (AWS requirement), others use pre-calculated mapping
            device_name = volume_name == "Root" ? "/dev/sda1" : local.workstation_device_map[workstation_key][volume_name]
        })
      }

      # OPTIONAL CONFIGURATION with 3-tier priority
      software_packages    = coalesce(config.software_packages, local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].software_packages : null, [])
      iam_instance_profile = config.iam_instance_profile != null ? config.iam_instance_profile : (local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].iam_instance_profile : null)
      additional_policy_arns = concat(
        config.additional_policy_arns,
        local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].additional_policy_arns : []
      )

      # INFRASTRUCTURE PLACEMENT (always workstation-specific, never from preset)
      subnet_id           = config.subnet_id
      availability_zone   = data.aws_subnet.workstation_subnets[workstation_key].availability_zone
      security_groups     = config.security_groups
      allowed_cidr_blocks = config.allowed_cidr_blocks

      # TAGS with merge priority: module < preset < workstation < required
      tags = merge(
        var.tags,                                                                                                      # Module default tags
        local.workstation_templates[workstation_key] != null ? local.workstation_templates[workstation_key].tags : {}, # Preset tags
        config.tags,                                                                                                   # Workstation-specific tags
        {                                                                                                              # Required tags (always applied)
          Name        = "${local.name_prefix}-${workstation_key}-workstation"
          Workstation = workstation_key
          Preset      = config.preset_key != null ? config.preset_key : "direct-config"
          Environment = var.environment
          Type        = "VDI-Workstation"
        }
      )
    }
  }



  processed_users = {
    for user_key, config in var.users : user_key => {
      given_name  = config.given_name
      family_name = config.family_name
      email       = config.email
      user_type   = "local"
      username    = user_key

      tags = merge(var.tags, config.tags, {
        User        = user_key
        GivenName   = config.given_name
        FamilyName  = config.family_name
        Email       = config.email
        UserType    = "Local"
        Environment = var.environment
        Type        = "VDI-User"
      })
    }
  }

  # STEP 3: Final EC2 instance configuration (simplified)
  # Merge workstation config with user assignment info
  final_instances = {
    for workstation_key, config in var.workstations : workstation_key => merge(
      local.processed_workstations[workstation_key],
      {
        # User assignment info (from assigned_user field)
        assigned_user    = config.assigned_user
        user_given_name  = config.assigned_user != null ? local.processed_users[config.assigned_user].given_name : null
        user_family_name = config.assigned_user != null ? local.processed_users[config.assigned_user].family_name : null
        user_email       = config.assigned_user != null ? local.processed_users[config.assigned_user].email : null

        # VDI-specific settings
        associate_public_ip_address     = true
        create_key_pair                 = true
        capacity_reservation_preference = config.capacity_reservation_preference != null ? config.capacity_reservation_preference : var.capacity_reservation_preference
      }
    )
  }

  # STEP 4: Final tags for instances
  assignment_tags = {
    for workstation_key, config in var.workstations : workstation_key => merge(
      local.processed_workstations[workstation_key].tags,
      config.assigned_user != null ? local.processed_users[config.assigned_user].tags : {},
      config.tags,
      {
        AssignedUser = config.assigned_user
        UserSource   = "local"
      }
    )
  }



  # Workstation-User combinations: Different user types have different access patterns
  workstation_user_combinations = merge(
    # Standard users: only on their assigned workstation
    {
      for workstation_key, config in var.workstations :
      "${workstation_key}-${config.assigned_user}" => {
        workstation = workstation_key
        user        = config.assigned_user
      }
      if config.assigned_user != null && var.users[config.assigned_user].type == "user"
    },
    # Local administrators: admin on their assigned workstation only
    {
      for workstation_key, config in var.workstations :
      "${workstation_key}-${config.assigned_user}" => {
        workstation = workstation_key
        user        = config.assigned_user
      }
      if config.assigned_user != null && var.users[config.assigned_user].type == "administrator"
    },
    # Fleet administrators: admin on ALL workstations (fleet management)
    {
      for combo in flatten([
        for workstation_key in keys(var.workstations) : [
          for user_key, user_config in var.users : {
            workstation = workstation_key
            user        = user_key
          }
          if user_config.type == "fleet_administrator"
        ]
      ]) : "${combo.workstation}-${combo.user}" => combo
    }
  )
}


resource "random_id" "suffix" {
  byte_length = 4
}
