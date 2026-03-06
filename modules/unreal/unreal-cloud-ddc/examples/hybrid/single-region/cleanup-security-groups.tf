# EKS Auto Mode Security Group Cleanup
# This runs at the example level to ensure it always executes during destroy
resource "terraform_data" "eks_security_group_cleanup" {
  input = {
    cluster_name = local.name_prefix
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "Starting EKS Auto Mode security group cleanup..."
      
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
          echo "SUCCESS: All EKS security groups cleaned up after $ATTEMPT minutes"
          exit 0
        fi
        
        # Aggressively clean up each security group
        for SG_ID in $ALL_SG_IDS; do
          if [ -n "$SG_ID" ]; then
            echo "Cleaning security group: $SG_ID"
            
            # Delete any dependent ENIs
            aws ec2 describe-network-interfaces \
              --filters "Name=group-id,Values=$SG_ID" \
              --query "NetworkInterfaces[].NetworkInterfaceId" --output text | \
              tr '\t' '\n' | while read ENI_ID; do
              if [ -n "$ENI_ID" ]; then
                echo "Deleting ENI: $ENI_ID"
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
            if ! aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null; then
              echo "Failed to delete security group $SG_ID - will retry"
            fi
          fi
        done
        
        sleep 60
        ATTEMPT=$((ATTEMPT + 1))
      done
      
      echo "WARNING: Security group cleanup incomplete after 30 minutes"
      exit 0  # Don't fail the destroy
    EOT
  }
}