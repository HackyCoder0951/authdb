output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "node_instance_types" {
  description = "Instance types configured for the managed node group."
  value       = local.eks_node_instance_types
}

output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Created public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "auth_service_ecr_repository_url" {
  description = "ECR repository URL for auth-service."
  value       = aws_ecr_repository.auth_service.repository_url
}

output "user_service_ecr_repository_url" {
  description = "ECR repository URL for user-service."
  value       = aws_ecr_repository.user_service.repository_url
}

output "task_service_ecr_repository_url" {
  description = "ECR repository URL for task-service."
  value       = aws_ecr_repository.task_service.repository_url
}

output "frontend_ecr_repository_url" {
  description = "ECR repository URL for frontend."
  value       = aws_ecr_repository.frontend.repository_url
}

output "docker_login_command" {
  description = "Command to authenticate Docker to this account's ECR registry."
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.auth_service.repository_url)[0]}"
}

output "frontend_load_balancer_hostname" {
  description = "Frontend AWS load balancer hostname. Available only after deploy_kubernetes=true and the service is provisioned."
  value       = var.deploy_kubernetes ? try(kubernetes_service_v1.frontend[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

