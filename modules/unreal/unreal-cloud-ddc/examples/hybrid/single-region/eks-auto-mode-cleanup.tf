# ##########################################
# # EKS Auto Mode Destroy Cleanup
# ##########################################

# # CRITICAL: EKS Auto Mode Limitation Workaround
# #
# # AWS EKS Auto Mode has a design gap where the DeleteCluster API does not block
# # until load balancers are cleaned up. This causes orphaned NLBs that prevent
# # VPC resource destruction with errors:
# #    - ACM Certificate: "Certificate is in use"
# #    - Security Groups: "Has dependent object"
# #    - Internet Gateway: "Has mapped public addresses"
# #
# # This provisioner automatically cleans up EKS-managed load balancers before
# # network resources are destroyed, preventing dependency violations.

# resource "terraform_data" "eks_auto_mode_nlb_cleanup" {
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
#       echo "Network resource destruction detected - cleaning up EKS Auto Mode load balancers"
#       
#       # Get VPC ID from triggers
#       VPC_ID="${self.triggers_replace[0]}"
#       
#       # Find and delete EKS-managed NLBs in this VPC
#       aws elbv2 describe-load-balancers \\
#         --query "LoadBalancers[?VpcId=='$VPC_ID' && starts_with(LoadBalancerName, 'k8s-')].LoadBalancerArn" \\
#         --output text | tr '\\t' '\\n' | while read -r LB_ARN; do
#         if [ -n "$LB_ARN" ]; then
#           echo "Deleting EKS Auto Mode load balancer: $LB_ARN"
#           aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" || true
#         fi
#       done
#       
#       # Wait for load balancers to be deleted
#       echo "Waiting for load balancers to be deleted..."
#       for i in {1..12}; do
#         REMAINING=$(aws elbv2 describe-load-balancers \\
#           --query "LoadBalancers[?VpcId=='$VPC_ID' && starts_with(LoadBalancerName, 'k8s-')].LoadBalancerArn" \\
#           --output text)
#         
#         if [ -z "$REMAINING" ]; then
#           echo "Load balancer cleanup complete - network resources can now be destroyed safely"
#           exit 0
#         else
#           echo "Waiting for load balancers to be deleted (attempt $i/12)..."
#           sleep 30
#         fi
#       done
#       
#       echo "Warning: Some load balancers may still be deleting - proceeding with destroy"
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