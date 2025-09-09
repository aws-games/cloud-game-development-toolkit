# Local variables for VDI module v2.0.0 - 5-Tier Architecture
locals {
  # Default AMI ID from data source
  default_ami_id = data.aws_ami.windows_server_2025.id

  # Random ID for unique resource naming
  random_id = random_id.suffix.hex

  # Base naming prefix
  name_prefix = "${var.project_prefix}-${var.environment}"
  
  # Single log group pattern (simplified)
  log_group_name = "/${var.project_prefix}/vdi/logs"
  
  # Storage configuration
  storage_settings = {
    encryption_enabled = var.ebs_encryption_enabled
    kms_key_id         = var.ebs_kms_key_id
  }

  # S3 bucket names (always created)
  s3_bucket_names = {
    keys    = "${var.project_prefix}-vdi-keys-${local.random_id}"
    scripts = "${var.project_prefix}-vdi-scripts-${local.random_id}"
  }
  
  # Authentication method inference
  has_ad_users = length(var.ad_users) > 0


  # Validate template references in workstations
  template_validation = {
    for workstation_key, config in var.workstations : workstation_key => {
      template_exists = contains(keys(var.templates), config.template_key)
      error_message   = "Workstation '${workstation_key}' references non-existent template '${config.template_key}'"
    }
  }

  # Validate user references in workstation assignments
  user_validation = {
    for workstation_key, config in var.workstation_assignments : workstation_key => {
      user_exists = config.user_source == "local" ? contains(keys(var.users), config.user) : contains(keys(var.ad_users), config.user)
      error_message = "Workstation '${workstation_key}' references non-existent user '${config.user}' in ${config.user_source}"
    }
  }

  # Validate workstation references in assignments
  workstation_validation = {
    for workstation_key, config in var.workstation_assignments : workstation_key => {
      workstation_exists = contains(keys(var.workstations), workstation_key)
      error_message = "Assignment references non-existent workstation '${workstation_key}'"
    }
  }

  # Process templates with intelligent defaults
  processed_templates = {
    for template_key, config in var.templates : template_key => {
      # Compute configuration
      ami           = config.ami != null ? config.ami : local.default_ami_id
      instance_type = config.instance_type
      gpu_enabled   = config.gpu_enabled
      
      # Software configuration
      software_packages = config.software_packages
      custom_scripts    = config.custom_scripts
      
      # Volume processing with Windows drive mapping
      volumes = {
        for volume_name, volume_config in config.volumes : volume_name => {
          capacity      = volume_config.capacity
          type          = volume_config.type
          windows_drive = volume_config.windows_drive
          iops          = volume_config.iops
          throughput    = volume_config.throughput
          encrypted     = volume_config.encrypted
          # Add device mapping for Windows (AWS supports /dev/sdf to /dev/sdp)
          device_name = volume_name == "Root" ? "/dev/sda1" : "/dev/sd${substr("fghijklmnop", index(keys(config.volumes), volume_name) - 1, 1)}"
        }
      }
      
      # Optional configuration
      iam_instance_profile = config.iam_instance_profile
      tags = merge(var.tags, config.tags, {
        Template = template_key
        Type     = "VDI-Template"
      })
    }
  }

  # Process workstations with template inheritance
  processed_workstations = {
    for workstation_key, config in var.workstations : workstation_key => merge(
      local.processed_templates[config.template_key],
      {
        # Infrastructure placement (workstation-specific)
        subnet_id         = config.subnet_id
        availability_zone = config.availability_zone
        security_groups   = config.security_groups
        
        # Software configuration (template + workstation overrides)
        final_software_packages = concat(
          [for pkg in local.processed_templates[config.template_key].software_packages : pkg if !contains(config.software_packages_exclusions, pkg)],
          config.software_packages_additions
        )
        
        # Script configuration (template + workstation)
        final_custom_scripts = concat(local.processed_templates[config.template_key].custom_scripts, config.custom_scripts)
        
        # Security and access
        allowed_cidr_blocks = config.allowed_cidr_blocks
        
        # Tags
        tags = merge(
          var.tags,
          local.processed_templates[config.template_key].tags,
          config.tags,
          {
            Name         = "${local.name_prefix}-${workstation_key}-workstation"
            Workstation  = workstation_key
            Template     = config.template_key
            Environment  = var.environment
            Type         = "VDI-Workstation"
          }
        )
      }
    )
  }


  # Process local users
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

  # Process AD users
  processed_ad_users = {
    for user_key, config in var.ad_users : user_key => {
      given_name       = config.given_name
      family_name      = config.family_name
      email            = config.email
      group_membership = config.group_membership
      user_type        = "ad"
      username         = user_key
      
      tags = merge(var.tags, config.tags, {
        User        = user_key
        GivenName   = config.given_name
        FamilyName  = config.family_name
        Email       = config.email
        UserType    = "ActiveDirectory"
        Environment = var.environment
        Type        = "VDI-AD-User"
      })
    }
  }

  # Process AD groups
  processed_ad_groups = var.enable_ad_integration ? {
    for group_key, config in var.ad_groups : group_key => {
      description = config.description
      
      tags = merge(var.tags, config.tags, {
        Group       = group_key
        Environment = var.environment
        Type        = "VDI-AD-Group"
      })
    }
  } : {}

  # Process workstation assignments with user lookup
  processed_assignments = {
    for workstation_key, config in var.workstation_assignments : workstation_key => {
      # Combined configuration for EC2 instance
      instance_config = merge(
        local.processed_workstations[workstation_key],
        {
          # User information
          assigned_user     = config.user
          user_source       = config.user_source
          user_given_name   = config.user_source == "local" ? local.processed_users[config.user].given_name : local.processed_ad_users[config.user].given_name
          user_family_name  = config.user_source == "local" ? local.processed_users[config.user].family_name : local.processed_ad_users[config.user].family_name
          user_email        = config.user_source == "local" ? local.processed_users[config.user].email : local.processed_ad_users[config.user].email
          user_type         = config.user_source == "local" ? local.processed_users[config.user].user_type : local.processed_ad_users[config.user].user_type
          
          # Always-enabled features for VDI
          associate_public_ip_address = true
          create_key_pair            = true  # Always create for break-glass access
        }
      )
      
      # Tags combining user, workstation, and assignment info
      tags = merge(
        var.tags,
        config.user_source == "local" ? local.processed_users[config.user].tags : local.processed_ad_users[config.user].tags,
        local.processed_workstations[workstation_key].tags,
        config.tags,
        {
          Name           = "${local.name_prefix}-${workstation_key}"
          WorkstationKey = workstation_key
          AssignedUser   = config.user
          UserSource     = config.user_source
          Template       = local.processed_workstations[workstation_key].tags.Template
          Environment    = var.environment
          Type           = "VDI-Assignment"
        }
      )
    }
  }

  # Check if any AD users are defined
  any_ad_users = length(var.ad_users) > 0
  
  # Validate AD configuration
  ad_validation_error = local.any_ad_users && !var.enable_ad_integration ? "AD users defined but enable_ad_integration = false" : null

  # Final configuration for EC2 instances (one per workstation assignment)
  final_instances = {
    for workstation_key, config in local.processed_assignments : workstation_key => config.instance_config
  }

  # Assignment tags for enhanced resource tracking
  assignment_tags = {
    for workstation_key, config in local.processed_assignments : workstation_key => config.tags
  }

  # Emergency key storage paths (S3) - always created
  emergency_key_paths = {
    for workstation_key, config in var.workstation_assignments : workstation_key => {
      bucket_name = local.s3_bucket_names.keys
      object_key  = "${workstation_key}/ec2-key/${workstation_key}-private-key.pem"
      full_path   = "s3://${local.s3_bucket_names.keys}/${workstation_key}/ec2-key/${workstation_key}-private-key.pem"
    }
  }

  # Installation script paths (S3) - always created
  installation_script_paths = {
    bucket_name = local.s3_bucket_names.scripts
    base_path   = "scripts/"
    runtime_path = "scripts/runtime/"
  }

  # Missing local values referenced in other files
  final_vdi_config = local.final_instances
  any_ad_join_required = var.enable_ad_integration && local.any_ad_users
  processed_groups = local.processed_ad_groups

  # Software package filtering for SSM associations - use final_software_packages
  chocolatey_workstations = toset([
    for assignment_key, config in local.processed_assignments : assignment_key
    if contains(config.instance_config.final_software_packages, "chocolatey")
  ])
  
  git_workstations = toset([
    for assignment_key, config in local.processed_assignments : assignment_key
    if contains(config.instance_config.final_software_packages, "git")
  ])
  
  visual_studio_workstations = toset([
    for assignment_key, config in local.processed_assignments : assignment_key
    if contains(config.instance_config.final_software_packages, "visual-studio-2022")
  ])
  
  unreal_engine_workstations = toset([
    for assignment_key, config in local.processed_assignments : assignment_key
    if contains(config.instance_config.final_software_packages, "unreal-engine-5.3")
  ])
  
  perforce_workstations = toset([
    for assignment_key, config in local.processed_assignments : assignment_key
    if contains(config.instance_config.final_software_packages, "perforce")
  ])

  # Custom scripts processing
  all_custom_scripts = flatten([
    for assignment_key, config in local.processed_assignments : [
      for script in config.instance_config.final_custom_scripts : {
        assignment_key = assignment_key
        script_path = script
        script_name = basename(script)
        is_s3 = startswith(script, "s3://")
        local_path = startswith(script, "s3://") ? null : (
          startswith(script, "/") ? script : "${path.root}/${script}"
        )
      }
    ]
  ])
  
  # Local scripts that need uploading to S3
  local_scripts_to_upload = {
    for script in local.all_custom_scripts : script.script_name => script
    if !script.is_s3
  }
  
  # Custom script associations
  custom_script_associations = {
    for script in local.all_custom_scripts : "${script.assignment_key}-${script.script_name}" => script
  }
}# Random ID for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}