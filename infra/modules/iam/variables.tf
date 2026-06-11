variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "msk_cluster_arn" {
  description = "MSK Serverless cluster ARN for Kafka IAM policy"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
