########################################
# EKS Auto Mode & External-DNS Cleanup Workarounds
########################################

# IMPORTANT: This addresses known AWS service bugs, not CGD Toolkit issues
#
# 1. EKS Auto Mode Bug: Security groups created for LoadBalancer services
#    are not cleaned up when the cluster is deleted, blocking VPC destruction
# 2. External-DNS Bug: DNS records created by External-DNS addon are not
#    cleaned up when the cluster is deleted
#
# These cleanup scripts only run when ddc_application_config is provided,
# as that's when LoadBalancer services (and thus security groups) are created

# Clean up External-DNS records that get orphaned during cluster destruction
resource "terraform_data" "cleanup_external_dns" {
  count = var.ddc_application_config != null ? 1 : 0

  # Store values at creation time for destroy-time use
  input = {
    route53_hosted_zone_name = var.route53_hosted_zone_name
    region                   = local.region
    environment              = var.environment
    cluster_name             = local.cluster_name
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "🧹 Cleanup Script: Handling External-DNS records (AWS External-DNS addon bug workaround)..."
      
      # Clean up External-DNS records from public zone (if configured)
      if [ -n "${self.input.route53_hosted_zone_name}" ]; then
        echo "Cleaning up External-DNS records from public zone: ${self.input.route53_hosted_zone_name}"
        PUBLIC_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${self.input.route53_hosted_zone_name}.'].Id" --output text | sed 's|/hostedzone/||')
        if [ -n "$PUBLIC_ZONE_ID" ]; then
          # Delete External-DNS created records for this cluster
          aws route53 list-resource-record-sets --hosted-zone-id "$PUBLIC_ZONE_ID" \
            --query "ResourceRecordSets[?contains(Name, '${self.input.region}.${self.input.environment}.ddc.${self.input.route53_hosted_zone_name}') && Type != 'NS' && Type != 'SOA']" \
            --output json > /tmp/dns_records.json
          
          # Process each record individually to avoid JSON parsing issues
          cat /tmp/dns_records.json | jq -c '.[]' | while read -r record; do
            if [ -n "$record" ]; then
              RECORD_NAME=$(echo "$record" | jq -r '.Name')
              RECORD_TYPE=$(echo "$record" | jq -r '.Type')
              echo "Deleting External-DNS record: $RECORD_NAME ($RECORD_TYPE)"
              
              # Create change batch file to avoid shell escaping issues
              echo '{"Changes":[{"Action":"DELETE","ResourceRecordSet":'"$record"'}]}' > /tmp/change_batch.json
              
              # Apply the change
              aws route53 change-resource-record-sets --hosted-zone-id "$PUBLIC_ZONE_ID" --change-batch file:///tmp/change_batch.json || {
                echo "Failed to delete $RECORD_NAME, continuing..."
              }
            fi
          done
          
          # Clean up temp files
          rm -f /tmp/dns_records.json /tmp/change_batch.json
        else
          echo "Public zone ${self.input.route53_hosted_zone_name} not found"
        fi
      else
        echo "No public zone configured, skipping External-DNS record cleanup"
      fi
      
      echo "External-DNS cleanup completed"
    EOT
  }
}

# Clean up EKS Auto Mode security groups that get orphaned during cluster destruction
resource "terraform_data" "cleanup_eks_auto_mode_security_groups" {
  count = var.ddc_application_config != null ? 1 : 0

  input = {
    cluster_name = local.cluster_name
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "🧹 Cleanup Script: Handling EKS Auto Mode security groups (AWS EKS Auto Mode bug workaround)..."
      echo "⚠️  This is a known AWS EKS Auto Mode issue - security groups are not cleaned up during cluster deletion"
      
      # 30 minutes = 1800 seconds, check every 60 seconds = 30 attempts
      MAX_ATTEMPTS=30
      ATTEMPT=1
      
      while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        echo "Cleanup attempt $ATTEMPT/$MAX_ATTEMPTS ($(($ATTEMPT)) minutes elapsed)..."
        
        # Find ALL EKS-related security groups
        SG_IDS=$(aws ec2 describe-security-groups \
          --filters "Name=tag:eks:eks-cluster-name,Values=${self.input.cluster_name}" \
          --query 'SecurityGroups[*].GroupId' --output text)
        
        # Also find k8s-traffic security groups
        K8S_SG_IDS=$(aws ec2 describe-security-groups \
          --filters "Name=group-name,Values=k8s-traffic-${self.input.cluster_name}-*" \
          --query 'SecurityGroups[*].GroupId' --output text)
        
        # Combine all security group IDs
        ALL_SG_IDS="$SG_IDS $K8S_SG_IDS"
        
        if [ -z "$(echo $ALL_SG_IDS | tr -d ' ')" ]; then
          echo "✅ SUCCESS: All EKS Auto Mode security groups cleaned up after $ATTEMPT minutes"
          exit 0
        fi
        
        # Aggressively clean up each security group
        for SG_ID in $ALL_SG_IDS; do
          if [ -n "$SG_ID" ]; then
            echo "Cleaning EKS Auto Mode security group: $SG_ID"
            
            # Delete any dependent ENIs
            aws ec2 describe-network-interfaces \
              --filters "Name=group-id,Values=$SG_ID" \
              --query "NetworkInterfaces[].NetworkInterfaceId" --output text | \
              tr '\t' '\n' | while read ENI_ID; do
              if [ -n "$ENI_ID" ]; then
                echo "Deleting dependent ENI: $ENI_ID"
                aws ec2 delete-network-interface --network-interface-id "$ENI_ID" || true
              fi
            done
            
            # Strip all rules from security group
            aws ec2 describe-security-groups --group-ids "$SG_ID" \
              --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
              jq -c '.[]?' 2>/dev/null | while read rule; do
              if [ -n "$rule" ]; then
                echo "$rule" | aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --ip-permissions file:///dev/stdin 2>/dev/null || true
              fi
            done
            
            # Try to delete the security group
            aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || true
          fi
        done
        
        sleep 60
        ATTEMPT=$((ATTEMPT + 1))
      done
      
      echo "⚠️  WARNING: EKS Auto Mode security group cleanup incomplete after 30 minutes"
      echo "Manual cleanup may be required - this is due to AWS EKS Auto Mode service limitations"
      exit 0  # Don't fail the destroy
    EOT
  }

  # This runs AFTER External-DNS cleanup
  depends_on = [terraform_data.cleanup_external_dns]
}