variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used for tagging and resource naming"
  type        = string
  default     = "capstone-sre"
}

variable "phase" {
  description = "Current phase (used in tags)"
  type        = string
  default     = "01"
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  default     = "dev"
}
