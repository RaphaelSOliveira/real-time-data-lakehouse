variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "delivery_stream_name" {
  description = "Name of the Firehose delivery stream"
  type        = string
  default     = "transaction_extraction"
}

variable "msk_cluster_arn" {
  description = "ARN of the source Amazon MSK cluster"
  type        = string
}

variable "topic_name" {
  description = "Kafka topic Firehose reads from"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the destination S3 bucket for the raw data"
  type        = string
}

variable "buffering_size" {
  description = "Buffer size in MB before Firehose delivers to S3"
  type        = number
  default     = 5
}

variable "buffering_interval" {
  description = "Buffer interval in seconds before Firehose delivers to S3"
  type        = number
  default     = 300
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
