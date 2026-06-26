output "job_name" {
  description = "Name of the Glue ETL job (use with: aws glue start-job-run --job-name <name>)"
  value       = aws_glue_job.riskops_transform.name
}

output "job_arn" {
  description = "ARN of the Glue ETL job"
  value       = aws_glue_job.riskops_transform.arn
}

output "role_arn" {
  description = "ARN of the IAM role the Glue job assumes"
  value       = aws_iam_role.glue.arn
}

output "script_location" {
  description = "S3 location of the uploaded PySpark transformation script"
  value       = local.script_location
}
