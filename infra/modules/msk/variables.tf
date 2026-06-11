variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for MSK Serverless (from networking module)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for MSK Serverless (from networking module)"
  type        = list(string)
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
