# Post-Module Updates Testing Guide

## Prerequisites (REQUIRED FIRST)
```bash
# Create SSM parameters in CI account
aws ssm put-parameter --name "/cgd-toolkit/tests/unreal-cloud-ddc/route53-public-hosted-zone-name" --value "your-domain.com" --type "String"
aws ssm put-parameter --name "/cgd-toolkit/tests/unreal-cloud-ddc/ghcr-credentials-secret-manager-arn" --value "arn:aws:secretsmanager:region:account:secret:ecr-pullthroughcache/name" --type "String"
```

## Test Strategy Overview

**Option 2 (Recommended)**: Test Scylla → Migration → Keyspaces in one flow
- Saves time by testing both database types and migration
- Validates real-world migration scenario
- Tests data preservation during migration

## Phase 1: Single-Region Testing

### Step 1: Deploy Scylla Baseline
```bash
cd examples/single-region-scylla/
terraform init
terraform apply
```

### Step 2: Validate Scylla Deployment
```bash
# Get connection info
terraform output scylla_instance_ids
terraform output ddc_endpoint

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check DDC pods
kubectl get pods -n unreal-cloud-ddc
kubectl logs -f <ddc-pod> -n unreal-cloud-ddc

# Verify DDC environment (should show Scylla config)
kubectl exec <ddc-pod> -n unreal-cloud-ddc -- env | grep -E "(Scylla|Database)"
```

### Step 3: Test DDC API & Populate Data
```bash
# Test DDC health
curl <ddc-endpoint>/health/live

# Write test data to populate Scylla
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/test-file-1" \
  --data "scylla-test-data-1" \
  -H "content-type: application/octet-stream" \
  -H "Authorization: ServiceAccount <bearer-token>"

curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/test-file-2" \
  --data "scylla-test-data-2" \
  -H "content-type: application/octet-stream" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Verify data retrieval
curl "<ddc-endpoint>/api/v1/refs/ddc/default/test-file-1.json" \
  -H "Authorization: ServiceAccount <bearer-token>"

curl "<ddc-endpoint>/api/v1/refs/ddc/default/test-file-2.json" \
  -H "Authorization: ServiceAccount <bearer-token>"
```

### Step 4: Validate Scylla Database (CRITICAL)
```bash
# Connect to Scylla instance
aws ssm start-session --target <instance-id-from-output>

# Inside Scylla instance
cqlsh

# CRITICAL: Document exact table structure for Keyspaces compatibility
DESCRIBE KEYSPACES;
USE jupiter_local_ddc_us_east_1;
DESCRIBE TABLES;

# Check each table schema (document for Keyspaces)
DESCRIBE TABLE cache_entries;
DESCRIBE TABLE s3_objects;
DESCRIBE TABLE namespace_config;
DESCRIBE TABLE cleanup_tracking;

# Verify data exists
SELECT COUNT(*) FROM cache_entries;
SELECT * FROM cache_entries LIMIT 5;
```

### Step 5: Enable Migration Mode & Deploy Keyspaces
```bash
# Edit main.tf to enable migration
database_migration_mode = true
database_migration_target = "scylla"  # Keep DDC on Scylla initially

# Add Keyspaces config (must match Scylla settings)
amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false
  peer_regions = []
}

# Apply migration (creates Keyspaces, DDC stays on Scylla)
terraform apply
```

### Step 6: Validate Keyspaces Creation
```bash
# Check Keyspaces resources
aws keyspaces get-keyspace --keyspace-name jupiter_local_ddc_us_east_1
aws keyspaces list-tables --keyspace-name jupiter_local_ddc_us_east_1

# Verify DDC still uses Scylla
kubectl exec <ddc-pod> -n unreal-cloud-ddc -- env | grep Database__Type
# Should still show: Database__Type=scylla
```

### Step 7: Manual Data Migration (Optional - Test Data Preservation)
```bash
# Export from Scylla
aws ssm start-session --target <scylla-instance-id>
cqlsh -e "COPY jupiter_local_ddc_us_east_1.cache_entries TO '/tmp/cache_entries.csv'"
cqlsh -e "COPY jupiter_local_ddc_us_east_1.s3_objects TO '/tmp/s3_objects.csv'"

# Transfer data (user-managed - use S3 or other method)
# Import to Keyspaces (user-managed - requires IAM auth setup)
```

### Step 8: Switch DDC to Keyspaces
```bash
# Edit main.tf to switch DDC target
database_migration_target = "keyspaces"  # Switch DDC to Keyspaces

# Apply switch (2-5 minutes downtime)
terraform apply
```

### Step 9: Validate Keyspaces Migration
```bash
# Verify DDC now uses Keyspaces
kubectl exec <ddc-pod> -n unreal-cloud-ddc -- env | grep Database__Type
# Should show: Database__Type=keyspaces

# Test DDC API with Keyspaces
curl <ddc-endpoint>/health/live

# Test new data (cache rebuild scenario)
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/keyspaces-test" \
  --data "keyspaces-test-data" \
  -H "content-type: application/octet-stream" \
  -H "Authorization: ServiceAccount <bearer-token>"

curl "<ddc-endpoint>/api/v1/refs/ddc/default/keyspaces-test.json" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Check if old data exists (if manual migration was done)
curl "<ddc-endpoint>/api/v1/refs/ddc/default/test-file-1.json" \
  -H "Authorization: ServiceAccount <bearer-token>"
```

### Step 10: Cleanup Migration
```bash
# Remove Scylla config
# scylla_config = { ... }  # DELETE THIS

# Apply cleanup (destroys Scylla resources)
terraform apply

# Disable migration mode
database_migration_mode = false

# Final apply
terraform apply

# Destroy everything
terraform destroy
```

## Phase 2: Keyspaces-Only Testing

### Step 1: Deploy Keyspaces Example
```bash
cd ../single-region-basic/  # Uses Keyspaces by default
terraform init
terraform apply
```

### Step 2: Validate Keyspaces Deployment
```bash
# Check Keyspaces resources
aws keyspaces get-keyspace --keyspace-name jupiter_local_ddc_us_east_1
aws keyspaces list-tables --keyspace-name jupiter_local_ddc_us_east_1

# Verify DDC uses Keyspaces
kubectl exec <ddc-pod> -n unreal-cloud-ddc -- env | grep Database__Type
# Should show: Database__Type=keyspaces

# Test DDC API
curl <ddc-endpoint>/health/live
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/keyspaces-only-test" \
  --data "keyspaces-only-data" \
  -H "content-type: application/octet-stream" \
  -H "Authorization: ServiceAccount <bearer-token>"

curl "<ddc-endpoint>/api/v1/refs/ddc/default/keyspaces-only-test.json" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Cleanup
terraform destroy
```

## Phase 3: Multi-Region Testing

### Step 1: Deploy Multi-Region Scylla
```bash
cd ../multi-region-scylla/
terraform init
terraform apply
```

### Step 2: Validate Multi-Region Scylla
```bash
# Get outputs for both regions
terraform output

# Test both regional endpoints
curl <us-east-1-endpoint>/health/live
curl <us-west-1-endpoint>/health/live

# Write data to primary region
curl -X PUT "<us-east-1-endpoint>/api/v1/refs/ddc/default/multi-region-test" \
  --data "multi-region-data" \
  -H "content-type: application/octet-stream" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Verify cross-region replication (check secondary region)
curl "<us-west-1-endpoint>/api/v1/refs/ddc/default/multi-region-test.json" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Check Scylla cluster status in both regions
aws ssm start-session --target <primary-instance-id>
nodetool status  # Should show both datacenters

aws ssm start-session --target <secondary-instance-id>
nodetool status  # Should show both datacenters
```

### Step 3: Multi-Region Migration (Optional)
```bash
# Follow same migration pattern as single-region
# Ensure peer_regions match between Scylla and Keyspaces configs
```

### Step 4: Test Multi-Region Keyspaces
```bash
cd ../multi-region-basic/
terraform init
terraform apply

# Test global tables functionality
# Write to one region, read from another
```

## Phase 4: Terraform Tests
```bash
cd ../../  # Back to module root
terraform init
terraform test
# Tests all 4 examples: single/multi-region × Keyspaces/Scylla
```

## Success Criteria Checklist

### Single-Region
- [ ] Scylla deployment successful
- [ ] DDC API works with Scylla (PUT/GET operations)
- [ ] Scylla table schemas documented
- [ ] Migration mode enables both databases
- [ ] DDC switches from Scylla to Keyspaces
- [ ] DDC API works with Keyspaces
- [ ] Clean migration cleanup
- [ ] Keyspaces-only deployment works

### Multi-Region
- [ ] Both regions deploy successfully
- [ ] Cross-region replication works (Scylla)
- [ ] Regional endpoints accessible
- [ ] Global tables work (Keyspaces)
- [ ] Data consistency across regions

### Migration
- [ ] Controlled migration with database_migration_target
- [ ] No service interruption during Keyspaces creation
- [ ] Smooth DDC switch (2-5 minutes downtime)
- [ ] Data preservation (if manual migration done)
- [ ] Clean Scylla resource cleanup

### Tests
- [ ] All 4 terraform tests pass
- [ ] SSM parameters work correctly
- [ ] Examples deploy without errors

## Critical Validation Points

1. **Table Schema Compatibility**: Scylla schemas must match pre-created Keyspaces tables
2. **Environment Variables**: DDC correctly detects database type
3. **Authentication**: Keyspaces IAM auth vs Scylla credentials
4. **Migration Control**: database_migration_target controls DDC connection
5. **Data Consistency**: Multi-region replication works for both databases

## Troubleshooting

**Common Issues:**
- DDC pods crash: Check environment variables and database connectivity
- Migration fails: Verify database configurations match exactly
- API timeouts: Check security groups and load balancer health
- Keyspaces auth fails: Verify EKS IRSA setup and IAM permissions

**Debug Commands:**
```bash
kubectl logs -f <ddc-pod> -n unreal-cloud-ddc
kubectl describe pod <ddc-pod> -n unreal-cloud-ddc
kubectl get events -n unreal-cloud-ddc --sort-by='.lastTimestamp'
```