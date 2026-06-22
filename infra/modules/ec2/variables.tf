variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID from networking module"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance into"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name from IAM module"
  type        = string
}

variable "public_key_path" {
  description = "Path to the local SSH public key file"
  type        = string
  default     = "~/.ssh/real-time-data-lakehouse.pub"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "msk_bootstrap_servers" {
  description = "MSK Serverless bootstrap broker endpoint (IAM/SASL)"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
