variable "aws_region" {
  description = "AWS region for all regional resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Value of ENVIRONMENT passed to the services; selects the /ecommerce/<environment>/ Parameter Store path."
  type        = string
  default     = "dev"
}

variable "cpu_architecture" {
  description = "Fargate CPU architecture. Must match the platform the Docker images were built for (ARM64 on Apple Silicon)."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "image_tag" {
  description = "Tag of the service images in ECR. deploy.sh sets a new tag on every run so ECS rolls out the new images."
  type        = string
  default     = "latest"
}

variable "notification_email" {
  description = "Email subscribed to order notifications (SNS). Leave empty to skip. AWS sends a confirmation link you must click."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "additional_cors_origins" {
  description = "Extra origins allowed to call the API besides the CloudFront domain, e.g. [\"http://localhost:3000\"] for local frontend dev."
  type        = list(string)
  default     = []
}
