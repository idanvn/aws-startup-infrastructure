output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.db_port
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
  
  🎉 Infrastructure deployed successfully!
  
  Next steps:
  1. Configure kubectl: ${module.eks.kubectl_config_command}
  2. Verify cluster: kubectl get nodes
  3. Database endpoint: ${module.rds.db_endpoint}
  4. CloudWatch logs: https://console.aws.amazon.com/cloudwatch
  
  EOT
}