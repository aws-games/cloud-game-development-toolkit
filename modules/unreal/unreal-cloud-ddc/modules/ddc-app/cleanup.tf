# Pre-destroy cleanup with explicit dependency chain
resource "null_resource" "pre_destroy_cleanup" {
  triggers = {
    cluster_name = var.cluster_name
    namespace    = var.namespace
    region       = var.region
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "🧹 Starting DDC pre-destroy cleanup..."
      
      # Configure kubectl context
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      # Remove TargetGroupBinding finalizers (prevents hanging)
      echo "Removing TargetGroupBinding finalizers..."
      kubectl get targetgroupbinding -n ${self.triggers.namespace} -o name 2>/dev/null | \
        xargs -I {} kubectl patch {} -n ${self.triggers.namespace} \
          --type='merge' -p='{"metadata":{"finalizers":null}}' || true
      
      # Remove service finalizers
      echo "Removing service finalizers..."
      kubectl get svc -n ${self.triggers.namespace} -o name 2>/dev/null | \
        xargs -I {} kubectl patch {} -n ${self.triggers.namespace} \
          --type='merge' -p='{"metadata":{"finalizers":null}}' || true
      
      # Uninstall DDC Helm release with wait
      echo "Uninstalling DDC Helm release..."
      helm uninstall ddc -n ${self.triggers.namespace} --wait --timeout=300s || true
      
      # Wait for AWS Load Balancer Controller to process deletions
      echo "Waiting for AWS Load Balancer Controller cleanup..."
      sleep 60
      
      echo "✅ DDC pre-destroy cleanup completed"
    EOT
  }

  # CRITICAL: This must depend on all Kubernetes resources
  # so it runs BEFORE they are destroyed
  depends_on = [
    helm_release.unreal_cloud_ddc_initialization,
    kubernetes_namespace.unreal_cloud_ddc,
    kubernetes_service_account.unreal_cloud_ddc_service_account
  ]
}