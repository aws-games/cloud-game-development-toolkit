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
  has_ad_users = false


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
      user_exists = contains(keys(var.users), config.user)
      error_message = "Workstation '${workstation_key}' references non-existent user '${config.user}'"
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
      
      # Software configuration removed - use custom AMIs
      
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
        
        # Software configuration removed - use custom AMIs
        
        # Script configuration removed (not implemented)
        
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

  # Process AD users (removed)
  processed_ad_users = {}

  # Process AD groups (removed)
  processed_ad_groups = {}

  # Process workstation assignments with user lookup
  processed_assignments = {
    for workstation_key, config in var.workstation_assignments : workstation_key => {
      # Combined configuration for EC2 instance
      instance_config = merge(
        local.processed_workstations[workstation_key],
        {
          # User information
          assigned_user     = config.user
          user_source       = "local"
          user_given_name   = local.processed_users[config.user].given_name
          user_family_name  = local.processed_users[config.user].family_name
          user_email        = local.processed_users[config.user].email
          user_type         = local.processed_users[config.user].user_type
          
          # Always-enabled features for VDI
          associate_public_ip_address = true
          create_key_pair            = true  # Always create for break-glass access
        }
      )
      
      # Tags combining user, workstation, and assignment info
      tags = merge(
        var.tags,
        local.processed_users[config.user].tags,
        local.processed_workstations[workstation_key].tags,
        config.tags,
        {
          Name           = "${local.name_prefix}-${workstation_key}"
          WorkstationKey = workstation_key
          AssignedUser   = config.user
          UserSource     = "local"
          Template       = local.processed_workstations[workstation_key].tags.Template
          Environment    = var.environment
          Type           = "VDI-Assignment"
        }
      )
    }
  }

  # Check if any AD users are defined (removed)
  any_ad_users = false
  
  # Validate AD configuration (removed)
  ad_validation_error = null

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
  any_ad_join_required = false
  processed_groups = {}

  # Software package filtering removed - use custom AMIs

  # Workstation-User combinations: Admin users on ALL workstations, Standard users on assigned workstations only
  workstation_user_combinations = merge(
    # Standard users: only on their assigned workstation
    {
      for assignment_key, assignment_config in var.workstation_assignments :
      "${assignment_key}-${assignment_config.user}" => {
        workstation = assignment_key
        user = assignment_config.user
      }
      if var.users[assignment_config.user].type == "user"
    },
    # Admin users: on ALL workstations
    {
      for combo in flatten([
        for workstation_key in keys(var.workstation_assignments) : [
          for user_key, user_config in var.users : {
            workstation = workstation_key
            user = user_key
          }
          if user_config.type == "administrator"
        ]
      ]) : "${combo.workstation}-${combo.user}" => combo
    }
  )
}# Random ID for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}