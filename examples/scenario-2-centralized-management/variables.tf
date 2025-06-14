variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "my-project-scenario-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "target_account_id" {
  description = "AWS Account ID where resources will be deployed"
  type        = string
  # No default - must be provided by user
}

variable "deployment_role_arn" {
  description = "ARN of the deployment role to assume"
  type        = string
  # No default - must be provided by user
}

variable "external_id" {
  description = "External ID for cross-account role assumption (should be unique per deployment)"
  type        = string
  # No default - must be provided by user for security
}

