variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "bucket_name" {
  description = "Name of the lakehouse S3 bucket (raw source and refined target live here)"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the lakehouse S3 bucket"
  type        = string
}

variable "topic_name" {
  description = "Dataset name; used to build the raw/ and refined/ prefixes"
  type        = string
  default     = "riskops_transaction"
}

variable "glue_version" {
  description = "AWS Glue version for the ETL job"
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Glue worker type (e.g. G.1X, G.2X)"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Number of Glue workers allocated to the job"
  type        = number
  default     = 2
}

variable "timeout_minutes" {
  description = "Job timeout in minutes before Glue terminates the run"
  type        = number
  default     = 60
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
