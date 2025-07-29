variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "intellibridge"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "flow-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity of the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "min_capacity" {
  description = "Minimum capacity of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
  default     = "132880019009.dkr.ecr.us-east-1.amazonaws.com"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for ALB"
  type        = string
  default     = ""
}

# Sensitive variables - should be provided via environment variables or secret management
variable "n8n_encryption_key" {
  description = "Encryption key for n8n"
  type        = string
  sensitive   = true
}

variable "opensearch_host" {
  description = "OpenSearch host URL with credentials"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "v1.0.0"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "flow.buildworkforce.ai"
}