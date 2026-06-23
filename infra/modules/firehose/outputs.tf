output "delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "delivery_stream_name" {
  description = "Name of the Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "role_arn" {
  description = "ARN of the IAM role Firehose assumes"
  value       = aws_iam_role.firehose.arn
}
