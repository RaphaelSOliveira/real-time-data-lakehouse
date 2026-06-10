/* 
variables.tf — Declares inputs that the root module accepts. 
Keeps all "what can change between environments" in one place. 
When you run terraform plan -var-file=environments/dev/terraform.tfvars, Terraform reads this file to know which variables are valid.
*/

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
  default     = "real-time-data-lakehouse"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for subnet placement (at least 2 required for MSK)"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (must match number of availability_zones)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
