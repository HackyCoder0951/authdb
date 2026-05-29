variable "aws_region" {
  description = "AWS region for EKS, ECR, VPC, and load balancer resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for AWS resources."
  type        = string
  default     = "authdb"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "authdb-prod"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the project VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks. Keep at least two subnets in different Availability Zones."
  type        = list(string)
  default     = ["10.40.0.0/20", "10.40.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required for the EKS control plane and load balancer."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. For better security, replace 0.0.0.0/0 with your office/home IP CIDR."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "node_desired_size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size for each worker node."
  type        = number
  default     = 40
}

variable "image_tag" {
  description = "Container image tag used by Kubernetes deployments."
  type        = string
  default     = "v1"
}

variable "deploy_kubernetes" {
  description = "Set true after the ECR repositories exist and images have been pushed."
  type        = bool
  default     = false
}

variable "enable_hpa" {
  description = "Create HorizontalPodAutoscalers. Requires metrics-server in the cluster."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Kubernetes namespace for AuthDB workloads."
  type        = string
  default     = "authdb"
}

variable "db_name" {
  description = "MongoDB database name."
  type        = string
  default     = "auth_scaleDB"
}

variable "mongodb_username" {
  description = "MongoDB root username."
  type        = string
  default     = "authdb_admin"
}

variable "mongodb_password" {
  description = "MongoDB root password. Leave null to generate one."
  type        = string
  default     = null
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ username."
  type        = string
  default     = "authdb"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password. Leave null to generate one."
  type        = string
  default     = null
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT SECRET_KEY value. Leave null to generate one."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Common tags for AWS resources."
  type        = map(string)
  default = {
    Project     = "authdb"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
