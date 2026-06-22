/*
outputs.tf — Exposes values after terraform apply (e.g., IDs, ARNs). 
Useful when you need to reference infra outputs in scripts or other systems.
This is always a standalone file so output logic doesn't get mixed with resource logic
*/
output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "s3_bucket_id" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}
