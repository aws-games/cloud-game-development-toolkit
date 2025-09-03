################################################################################
# Amazon Keyspaces Resources (Conditional on amazon_keyspaces_config != null)
################################################################################

################################################################################
# Keyspace Creation (AWSCC Provider for both single and multi-region)
################################################################################

resource "awscc_cassandra_keyspace" "keyspaces" {
  for_each = var.amazon_keyspaces_config != null ? var.amazon_keyspaces_config.keyspaces : {}
  
  keyspace_name = each.key
  
  replication_specification = each.value.enable_cross_region_replication ? {
    replication_strategy = "MULTI_REGION"
    region_list = concat([var.region], each.value.peer_regions)
  } : null
  
  tags = [
    {
      key = "Name"
      value = "${local.name_prefix}-${each.key}"
    },
    {
      key = "DatabaseType"
      value = "amazon-keyspaces"
    }
  ]
}

################################################################################
# DDC Table Schemas (Pre-created for clean state management)
################################################################################

# Cache entries table - stores metadata about cached objects
resource "aws_keyspaces_table" "cache_entries" {
  for_each = var.amazon_keyspaces_config != null ? {
    for keyspace_name, config in var.amazon_keyspaces_config.keyspaces :
    keyspace_name => config if !config.enable_cross_region_replication
  } : {}
  
  keyspace_name = awscc_cassandra_keyspace.keyspaces[each.key].keyspace_name
  table_name    = "cache_entries"
  
  schema_definition {
    column {
      name = "namespace"
      type = "text"
    }
    column {
      name = "key"
      type = "text"
    }
    column {
      name = "value"
      type = "blob"
    }
    column {
      name = "last_access_time"
      type = "timestamp"
    }
    
    partition_key {
      name = "namespace"
    }
    
    clustering_key {
      name = "key"
      order_by = "ASC"
    }
  }
  
  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery ? [1] : []
    content {
      status = "ENABLED"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-${each.key}-cache-entries"
    TableType = "ddc-cache-metadata"
  })
}

# Global cache entries table for multi-region
resource "aws_keyspaces_table" "cache_entries_global" {
  for_each = var.amazon_keyspaces_config != null ? {
    for keyspace_name, config in var.amazon_keyspaces_config.keyspaces :
    keyspace_name => config if config.enable_cross_region_replication
  } : {}
  
  keyspace_name = awscc_cassandra_keyspace.keyspaces[each.key].keyspace_name
  table_name    = "cache_entries"
  
  schema_definition {
    column {
      name = "namespace"
      type = "text"
    }
    column {
      name = "key"
      type = "text"
    }
    column {
      name = "value"
      type = "blob"
    }
    column {
      name = "last_access_time"
      type = "timestamp"
    }
    
    partition_key {
      name = "namespace"
    }
    
    clustering_key {
      name = "key"
      order_by = "ASC"
    }
  }
  
  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery ? [1] : []
    content {
      status = "ENABLED"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-${each.key}-cache-entries-global"
    TableType = "ddc-cache-metadata-global"
  })
}

# S3 objects table - maps cache keys to S3 object locations
resource "aws_keyspaces_table" "s3_objects" {
  for_each = var.amazon_keyspaces_config != null ? var.amazon_keyspaces_config.keyspaces : {}
  
  keyspace_name = awscc_cassandra_keyspace.keyspaces[each.key].keyspace_name
  table_name    = "s3_objects"
  
  schema_definition {
    column {
      name = "namespace"
      type = "text"
    }
    column {
      name = "cache_key"
      type = "text"
    }
    column {
      name = "s3_bucket"
      type = "text"
    }
    column {
      name = "s3_key"
      type = "text"
    }
    column {
      name = "size_bytes"
      type = "bigint"
    }
    column {
      name = "created_time"
      type = "timestamp"
    }
    
    partition_key {
      name = "namespace"
    }
    
    clustering_key {
      name = "cache_key"
      order_by = "ASC"
    }
  }
  
  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery ? [1] : []
    content {
      status = "ENABLED"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-${each.key}-s3-objects"
    TableType = "ddc-s3-mapping"
  })
}

# Namespace configuration table - stores DDC namespace settings
resource "aws_keyspaces_table" "namespace_config" {
  for_each = var.amazon_keyspaces_config != null ? var.amazon_keyspaces_config.keyspaces : {}
  
  keyspace_name = awscc_cassandra_keyspace.keyspaces[each.key].keyspace_name
  table_name    = "namespace_config"
  
  schema_definition {
    column {
      name = "namespace"
      type = "text"
    }
    column {
      name = "config_key"
      type = "text"
    }
    column {
      name = "config_value"
      type = "text"
    }
    column {
      name = "updated_time"
      type = "timestamp"
    }
    
    partition_key {
      name = "namespace"
    }
    
    clustering_key {
      name = "config_key"
      order_by = "ASC"
    }
  }
  
  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery ? [1] : []
    content {
      status = "ENABLED"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-${each.key}-namespace-config"
    TableType = "ddc-configuration"
  })
}

# Cleanup tracking table - tracks garbage collection operations
resource "aws_keyspaces_table" "cleanup_tracking" {
  for_each = var.amazon_keyspaces_config != null ? var.amazon_keyspaces_config.keyspaces : {}
  
  keyspace_name = awscc_cassandra_keyspace.keyspaces[each.key].keyspace_name
  table_name    = "cleanup_tracking"
  
  schema_definition {
    column {
      name = "namespace"
      type = "text"
    }
    column {
      name = "cleanup_id"
      type = "text"
    }
    column {
      name = "status"
      type = "text"
    }
    column {
      name = "started_time"
      type = "timestamp"
    }
    column {
      name = "completed_time"
      type = "timestamp"
    }
    
    partition_key {
      name = "namespace"
    }
    
    clustering_key {
      name = "cleanup_id"
      order_by = "ASC"
    }
  }
  
  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery ? [1] : []
    content {
      status = "ENABLED"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-${each.key}-cleanup-tracking"
    TableType = "ddc-maintenance"
  })
}