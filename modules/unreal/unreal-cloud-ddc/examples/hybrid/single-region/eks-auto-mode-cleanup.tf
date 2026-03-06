# ##########################################
# # EKS Auto Mode Destroy Cleanup
# ##########################################

# # CRITICAL: EKS Auto Mode Limitation Workaround
# #
# # AWS EKS Auto Mode has a design gap where the DeleteCluster API does not block
# # until load balancers are cleaned up. This causes orphaned resources that prevent
# # VPC resource destruction with errors:
# #    - ACM Certificate: "Certificate is in use"
# #    - Security Groups: "Has dependent object"
# #    - Internet Gateway: "Has mapped public addresses"
# #
# # This provisioner automatically cleans up EKS-managed resources with retry logic
# # before network resources are destroyed, preventing dependency violations.

# resource "terraform_data" "eks_auto_mode_cleanup" {
#   triggers_replace = [
#     aws_vpc.main.id,
#     aws_internet_gateway.main.id,
#     join(",", aws_subnet.private[*].id),
#     join(",", aws_subnet.public[*].id)
#   ]
#   
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       echo "Network resource destruction detected - cleaning up EKS Auto Mode resources"
#       
#       # Get VPC ID from triggers
#       VPC_ID="${self.triggers_replace[0]}"
#       
#       # Retry function for resource cleanup
#       cleanup_with_retry() {
#         local resource_type="$1"
#         local max_attempts=20
#         local attempt=1
#         
#         while [ $attempt -le $max_attempts ]; do
#           echo "Attempt $attempt/$max_attempts: Cleaning up $resource_type..."
#           
#           case "$resource_type" in
#             "load_balancers")
#               # Find and delete EKS-managed NLBs in this VPC
#               aws elbv2 describe-load-balancers \\
#                 --query "LoadBalancers[?VpcId=='$VPC_ID' && starts_with(LoadBalancerName, 'k8s-')].LoadBalancerArn" \\
#                 --output text | tr '\\t' '\\n' | while read -r LB_ARN; do
#                 if [ -n "$LB_ARN" ]; then
#                   echo "Deleting EKS Auto Mode load balancer: $LB_ARN"
#                   aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" || true
#                 fi
#               done
#               ;;
#             "security_groups")
#               # Find and delete EKS-managed security groups
#               aws ec2 describe-security-groups \\
#                 --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-traffic-*" \\
#                 --query "SecurityGroups[].GroupId" --output text | tr '\\t' '\\n' | while read -r SG_ID; do
#                 if [ -n "$SG_ID" ]; then
#                   echo "Attempting to delete security group: $SG_ID"
#                   # First try to delete any dependent ENIs
#                   aws ec2 describe-network-interfaces \\
#                     --filters "Name=group-id,Values=$SG_ID" \\
#                     --query "NetworkInterfaces[].NetworkInterfaceId" --output text | tr '\\t' '\\n' | while read -r ENI_ID; do
#                     if [ -n "$ENI_ID" ]; then
#                       echo "Deleting dependent ENI: $ENI_ID"
#                       aws ec2 delete-network-interface --network-interface-id "$ENI_ID" || true
#                     fi
#                   done
#                   # Then try to delete the security group
#                   aws ec2 delete-security-group --group-id "$SG_ID" || true
#                 fi
#               done
#               ;;
#           esac
#           
#           # Check if cleanup is complete
#           case "$resource_type" in
#             "load_balancers")
#               REMAINING=$(aws elbv2 describe-load-balancers \\
#                 --query "LoadBalancers[?VpcId=='$VPC_ID' && starts_with(LoadBalancerName, 'k8s-')].LoadBalancerArn" \\
#                 --output text)
#               ;;
#             "security_groups")
#               REMAINING=$(aws ec2 describe-security-groups \\
#                 --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-traffic-*" \\
#                 --query "SecurityGroups[].GroupId" --output text)
#               ;;
#           esac
#           
#           if [ -z "$REMAINING" ]; then
#             echo "$resource_type cleanup complete"
#             return 0
#           fi
#           
#           echo "$resource_type still exist, waiting 15 seconds before retry..."
#           sleep 15
#           attempt=$((attempt + 1))
#         done
#         
#         echo "Warning: $resource_type cleanup incomplete after $max_attempts attempts"
#         return 1
#       }
#       
#       # Clean up load balancers first
#       cleanup_with_retry "load_balancers"
#       
#       # Then clean up security groups
#       cleanup_with_retry "security_groups"
#       
#       echo "EKS Auto Mode cleanup completed - network resources can now be destroyed"
#     EOT
#   }
#   
#   depends_on = [
#     aws_vpc.main,
#     aws_internet_gateway.main,
#     aws_subnet.private,
#     aws_subnet.public
#   ]
# }