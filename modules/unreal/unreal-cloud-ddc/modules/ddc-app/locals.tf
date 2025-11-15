################################################################################
# BASIC CONFIGURATION (Not fed into yamlencode)
################################################################################

locals {
  # Standard naming pattern → Used in yamlencode (fullnameOverride)
  name_prefix = "${var.project_prefix}-${var.name}-${var.environment}"

  # Deployment orchestration settings → Used by null_resource provisioners (NOT yamlencode)
  cluster_ready_timeout_minutes = var.ddc_application_config.cluster_ready_timeout_minutes
  enable_ddc_readiness_check    = var.ddc_application_config.enable_single_region_validation
  ddc_readiness_timeout_minutes = var.ddc_application_config.single_region_validation_timeout_minutes

  # Logging configuration → Used by CloudWatch resources (NOT yamlencode)
  log_group_prefix    = var.log_group_prefix
  ddc_logging_enabled = var.enable_centralized_logging
  
  # Simple NVMe storage strategy - always use i-family instances
  # EKS Auto Mode will choose appropriate i-family instance (i3, i4i, etc.)
  # All i-family instances have NVMe drives mounted at /mnt/.ephemeral
}

################################################################################
# DATABASE CONNECTION ABSTRACTION → Fed into yamlencode
################################################################################

locals {
  # Legacy ScyllaDB connection fallback → Used in yamlencode (Scylla.ConnectionString)
  # TODO: Remove legacy variables once all modules use database_connection object
  database_connection_string = var.scylla_dns_name != null && var.scylla_dns_name != "" ? var.scylla_dns_name : (
    length(var.scylla_ips) > 0 ? join(",", var.scylla_ips) : var.database_connection.host
  )

  # ScyllaDB datacenter name → Used in yamlencode (Scylla.LocalDatacenterName)
  datacenter_name = var.scylla_datacenter_name != null ? var.scylla_datacenter_name : (
    var.region != null ? replace(var.region, "-1", "") : ""
  )
}

################################################################################
# MULTI-REGION REPLICATION LOGIC → Fed into yamlencode
################################################################################

locals {
  # Remote DDC servers for on-demand replication → Used in yamlencode (config.DDC.RemoteDDCServers)
  # Only includes regions different from current region
  remote_ddc_servers = var.ddc_application_config.enable_multi_region_replication && contains(["on-demand", "hybrid"], var.ddc_application_config.replication_mode) && var.ddc_application_config.ddc_namespaces != null ? flatten([
    for namespace_name, namespace_config in var.ddc_application_config.ddc_namespaces : 
      namespace_config.regions != null ? [
        for region in namespace_config.regions : 
          "https://${replace(var.ddc_endpoint_pattern, var.region, region)}"
        if region != var.region
      ] : []
  ]) : []

  # Replicators for speculative replication → Used in yamlencode (worker.config.GC.Replication.Replicators)
  # Creates named replicators for each remote region
  replicators = var.ddc_application_config.enable_multi_region_replication && contains(["speculative", "hybrid"], var.ddc_application_config.replication_mode) && var.ddc_application_config.ddc_namespaces != null ? flatten([
    for namespace_name, namespace_config in var.ddc_application_config.ddc_namespaces : 
      namespace_config.regions != null ? [
        for region in namespace_config.regions : {
          ReplicatorName   = "${namespace_name}-${region}-replicator"
          Namespace        = namespace_name
          ConnectionString = "https://${replace(var.ddc_endpoint_pattern, var.region, region)}"
        }
        if region != var.region
      ] : []
  ]) : []
}

################################################################################
# DDC NAMESPACE POLICIES → Fed into yamlencode
################################################################################

locals {
  # Build namespace access control policies → Used in yamlencode (global.namespaces.Policies)
  # Combines configured namespaces + default namespace (if specified)
  namespace_policies = merge(
    # DDC namespaces from configuration
    {
      for namespace_name, namespace_config in var.ddc_application_config.ddc_namespaces : namespace_name => {
        acls = [{
          actions = ["ReadObject", "WriteObject"]
          claims  = ["groups=${var.ddc_application_config.ddc_access_group}"]
        }]
      }
    },
    # Default namespace (for testing/fallback)
    var.ddc_application_config.default_ddc_namespace != "" ? {
      "${var.ddc_application_config.default_ddc_namespace}" = {
        acls = [{
          actions = ["ReadObject", "WriteObject"]
          claims  = ["groups=${var.ddc_application_config.ddc_access_group}"]
        }]
      }
    } : {}
  )
}

################################################################################
# HELM VALUES GENERATION (yamlencode approach)
################################################################################
# 
# This section defines the complete Helm values structure using native HCL syntax.
# ALL locals defined above are consumed here and fed into yamlencode():
# 
# • name_prefix → fullnameOverride
# • database_connection_string → Scylla.ConnectionString (main + worker)
# • datacenter_name → Scylla.LocalDatacenterName
# • remote_ddc_servers → config.DDC.RemoteDDCServers
# • replicators → worker.config.GC.Replication.Replicators
# • namespace_policies → global.namespaces.Policies
# 
# WHY yamlencode() over templatefile():
# ✅ Guaranteed valid YAML output (no syntax errors)
# ✅ Type safety - Terraform validates HCL structure at plan time
# ✅ Better IDE support (autocomplete, syntax highlighting)
# ✅ Easier maintenance - no mixed HCL/YAML templating
# ✅ Cleaner code - no %{ for } loops in templates
# ✅ Better error messages for invalid configurations
# 
# Trade-off: Large diffs in terraform plan when values change
# (acceptable for much cleaner, maintainable source code)
################################################################################

locals {
  # Generate Helm values for DDC deployment
  # This structure is optimized for Epic's official chart
  # Custom charts may require different value structures
  ddc_helm_values = {
      
      ########################################
      # BASIC CHART CONFIGURATION
      ########################################
      
      fullnameOverride = local.name_prefix
      replicaCount     = var.ddc_application_config.replica_count
      
      # Container image configuration
      image = {
        repository = split(":", var.ddc_application_config.container_image)[0]
        tag        = length(split(":", var.ddc_application_config.container_image)) > 1 ? split(":", var.ddc_application_config.container_image)[1] : "1.2.0"
        pullPolicy = "IfNotPresent"
      }
      
      ########################################
      # KUBERNETES RESOURCES
      ########################################
      
      # Service account with IRSA for AWS permissions
      serviceAccount = {
        create = true
        name   = var.kubernetes_service_account_name
        annotations = var.service_account_arn != null ? {
          "eks.amazonaws.com/role-arn" = var.service_account_arn
        } : {}
      }
      
      # Target i-family instances with NVMe storage (EKS Auto Mode)
      nodeSelector = {
        "eks.amazonaws.com/instance-category" = "i"
      }
      
      # Resource requests for pod scheduling
      resources = {
        requests = {
          cpu    = var.ddc_application_config.cpu_requests
          memory = var.ddc_application_config.memory_requests
        }
      }
      
      ########################################
      # LOAD BALANCER SERVICE
      ########################################
      
      service = {
        type     = "LoadBalancer"  # AWS Load Balancer Controller creates NLB
        portName = "http"
        port     = 80
        targetPort = "http"
        
        # AWS Load Balancer Controller annotations
        annotations = merge(
          {
            # NLB configuration (from parent module load_balancers_config)
            "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = var.load_balancers_config != null && var.load_balancers_config.nlb != null ? (var.load_balancers_config.nlb.internet_facing ? "internet-facing" : "internal") : "internet-facing"
            
            # EKS Auto Mode requires IP targeting (not Instance targeting)
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            
            # Health check configuration for DDC endpoints
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"                = "/health/live"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"            = "HTTP"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"                = "80"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval"            = "30"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout"             = "5"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold"   = "2"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold" = "2"
          },
          # External-DNS annotation for Route53 record creation
          var.ddc_endpoint_pattern != null ? {
            "external-dns.alpha.kubernetes.io/hostname" = var.ddc_endpoint_pattern
          } : {},
          # Subnet placement handled by EKS cluster subnet configuration
          # HTTPS listener (when certificate provided)
          var.certificate_arn != null ? {
            "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"        = var.certificate_arn
            "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"       = "443"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
          } : {}
        )
        
        # Additional ports (HTTPS only when certificate available)
        # NOTE: Removed HTTP/2 port 8080 → "nginx-h2" since nginx.enabled = false
        extraPort = var.certificate_arn != null ? [{
          name       = "https"
          port       = 443
          targetPort = "http"  # Routes to same Kestrel port 80
        }] : []
      }
      
      ########################################
      # APPLICATION CONFIGURATION
      ########################################
      
      # Environment variables for ASP.NET Core Kestrel
      env = [
        { name = "ASPNETCORE_URLS", value = "http://0.0.0.0:80" },
        { name = "ASPNETCORE_HTTP_PORTS", value = "80" },
        { name = "Kestrel__Endpoints__Http__Url", value = "http://0.0.0.0:80" },
        { name = "Database__Type", value = "scylla" },
        { name = "Database__Host", value = local.database_connection_string },
        { name = "Database__Port", value = tostring(var.database_connection.port) },
        { name = "Database__AuthType", value = var.database_connection.auth_type }
      ]
      
      # Disable NGINX proxy (direct Kestrel access)
      nginx = {
        enabled          = false
        useDomainSockets = false
      }
      
      # NVMe storage configuration (all i-family instances have NVMe)
      persistence = {
        enabled   = false
        mountPath = "/data"
        volume = {
          hostPath = {
            path = "/mnt/.ephemeral"
            type = "DirectoryOrCreate"
          }
        }
      }
      
      ########################################
      # DDC APPLICATION CONFIG
      ########################################
      
      config = {
        # S3 storage backend
        S3 = {
          BucketName = var.s3_bucket_id != null ? var.s3_bucket_id : ""
        }
        
        # Remote DDC servers for replication (conditional)
        DDC = length(local.remote_ddc_servers) > 0 ? {
          RemoteDDCServers = local.remote_ddc_servers
        } : {}
        
        # ScyllaDB database configuration
        Scylla = {
          ConnectionString = "Contact Points=${local.database_connection_string};Port=${var.database_connection.port};Default Keyspace=${var.database_connection.keyspace_name};"
          KeyspaceReplicationStrategy = {
            class = "NetworkTopologyStrategy"
            "${local.datacenter_name}" = var.replication_factor
          }
          LocalDatacenterName = local.datacenter_name
          LocalKeyspaceSuffix = "ddc"
        }
        
        # Local filesystem cache (800GB limit)
        Filesystem = {
          MaxSizeBytes = 800000000000
        }
        
        # Database implementation selection
        UnrealCloudDDC = {
          BlobIndexImplementation        = "Scylla"
          ContentIdStoreImplementation   = "Scylla"
          ReferencesDbImplementation     = "Scylla"
          ReplicationLogWriterImplementation = "Scylla"
        }
        
        # Authentication configuration
        ServiceAccounts = {
          Accounts = [{
            Token = var.ddc_bearer_token != null ? var.ddc_bearer_token : ""
            Claims = [
              "groups:${var.ddc_application_config.ddc_access_group}",
              "groups:${var.ddc_application_config.ddc_admin_group}"
            ]
          }]
        }
      }
      
      ########################################
      # GLOBAL DDC CONFIGURATION
      ########################################
      
      global = {
        cloudProvider = "AWS"
        awsRegion     = var.region != null ? var.region : ""
        siteName      = var.region != null ? var.region : ""
        awsRole       = "AssumeRoleWebIdentity"
        
        # Authentication schemes
        auth = {
          defaultScheme = "ServiceAccount"
          schemes = {
            ServiceAccount = {
              implementation = "ServiceAccount"
            }
          }
          # Admin access control
          acls = [{
            claims  = ["groups=${var.ddc_application_config.ddc_admin_group}"]
            actions = ["ReadObject", "WriteObject", "DeleteObject", "DeleteBucket", "DeleteNamespace", "AdminAction"]
          }]
        }
        
        # Namespace access policies
        namespaces = {
          Policies = local.namespace_policies
        }
      }
      
      ########################################
      # WORKER CONFIGURATION
      ########################################
      
      worker = {
        enabled = true
        
        # Worker-specific configuration
        config = {
          # Garbage collection settings
          GC = {
            CleanOldRefRecords = true
            CleanOldBlobs      = true
            Replication = merge(
              { Enabled = var.ddc_application_config.enable_multi_region_replication },
              length(local.replicators) > 0 ? { Replicators = local.replicators } : {}
            )
          }
          
          # Database implementations (same as main service)
          UnrealCloudDDC = {
            BlobIndexImplementation        = "Scylla"
            ContentIdStoreImplementation   = "Scylla"
            ReferencesDbImplementation     = "Scylla"
            ReplicationLogWriterImplementation = "Scylla"
            StorageImplementations         = ["S3"]
          }
          
          # ScyllaDB connection (duplicate for worker)
          Scylla = {
            ConnectionString = "Contact Points=${local.database_connection_string};Port=${var.database_connection.port};Default Keyspace=${var.database_connection.keyspace_name};"
            KeyspaceReplicationStrategy = {
              class = "NetworkTopologyStrategy"
              "${local.datacenter_name}" = var.replication_factor
            }
            LocalDatacenterName = local.datacenter_name
            LocalKeyspaceSuffix = "ddc"
          }
          
          # S3 configuration (duplicate for worker)
          S3 = {
            BucketName = var.s3_bucket_id != null ? var.s3_bucket_id : ""
          }
        }
        
        # Worker resource allocation - i-family instances with NVMe
        nodeSelector = {
          "eks.amazonaws.com/instance-category" = "i"
        }
        resources = {
          requests = {
            cpu    = var.ddc_application_config.worker_cpu_requests
            memory = var.ddc_application_config.worker_memory_requests
          }
        }
      }
    }
  }

################################################################################
# YAML FILE GENERATION
################################################################################
# 
# Convert HCL structure to YAML for Helm deployment
# Creates both internal (module) and debug (user-visible) files
################################################################################

locals {
  # Use custom values if provided, otherwise use generated Epic values
  final_helm_values = var.ddc_application_config.custom_helm_values != null ? var.ddc_application_config.custom_helm_values : local.ddc_helm_values
    
  # Convert final values to YAML for Helm deployment
  helm_values_yaml = yamlencode(local.final_helm_values)
}

# Module-internal values file → consumed by null_resource helm deployment
resource "local_file" "ddc_helm_values" {
  content  = local.helm_values_yaml
  filename = "${path.module}/generated/helm-values/unreal-cloud-ddc-values.yaml"
}

# User-visible debug file → created in example root when debug=true
resource "local_file" "debug_helm_values" {
  count = var.debug ? 1 : 0
  
  content  = local.helm_values_yaml
  filename = "${path.root}/generated/helm-values/debug-unreal-cloud-ddc-values.yaml"
}