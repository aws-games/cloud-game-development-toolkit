########################################
# External-DNS and EKS Auto Mode Cleanup
########################################

# Clean up External-DNS records and EKS Auto Mode security groups that get orphaned during cluster destruction
resource "terraform_data" "cleanup_eks_stragglers" {
  count = var.ddc_infra_config != null ? 1 : 0

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
      echo "Starting External-DNS and EKS Auto Mode cleanup..."
      
      # Clean up External-DNS records from public zone (if configured)
      if [ -n "${self.input.route53_hosted_zone_name}" ]; then
        echo "Cleaning up External-DNS records from public zone: ${self.input.route53_hosted_zone_name}"
        PUBLIC_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${self.input.route53_hosted_zone_name}.'].Id" --output text | sed 's|/hostedzone/||')
        if [ -n "$PUBLIC_ZONE_ID" ]; then
          # Delete External-DNS created records for this cluster
          aws route53 list-resource-record-sets --hosted-zone-id "$PUBLIC_ZONE_ID" \
            --query "ResourceRecordSets[?contains(Name, '${self.input.region}.${self.input.environment}.ddc.${self.input.route53_hosted_zone_name}') && Type != 'NS' && Type != 'SOA']" \
            --output json | jq -c '.[]' | while read record; do
            if [ -n "$record" ]; then
              echo "Deleting External-DNS record: $(echo "$record" | jq -r '.Name')"
              echo '{"Changes":[{"Action":"DELETE","ResourceRecordSet":'$record'}]}' | \
                aws route53 change-resource-record-sets --hosted-zone-id "$PUBLIC_ZONE_ID" --change-batch file:///dev/stdin || true
            fi
          done
        else
          echo "Public zone ${self.input.route53_hosted_zone_name} not found"
        fi
      else
        echo "No public zone configured, skipping External-DNS record cleanup"
      fi
      
      # Clean up EKS Auto Mode security groups by tags
      echo "Cleaning up EKS Auto Mode security groups..."
      aws ec2 describe-security-groups \
        --filters "Name=tag:eks:eks-cluster-name,Values=${self.input.cluster_name}" \
                  "Name=tag:service.eks.amazonaws.com/resource,Values=ManagedBackendSecurityGroup" \
        --query 'SecurityGroups[*].GroupId' --output text | \
        xargs -r -n1 sh -c 'echo "Deleting EKS Auto Mode security group: $1" && aws ec2 delete-security-group --group-id "$1" || true' _
      
      # Clean up k8s-traffic security groups by name pattern
      echo "Cleaning up k8s-traffic security groups..."
      aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=k8s-traffic-${self.input.cluster_name}-*" \
        --query 'SecurityGroups[*].GroupId' --output text | \
        xargs -r -n1 sh -c 'echo "Deleting k8s-traffic security group: $1" && aws ec2 delete-security-group --group-id "$1" || true' _
      
      echo "External-DNS and EKS Auto Mode cleanup completed"
    EOT
  }
}