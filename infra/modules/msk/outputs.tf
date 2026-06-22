output "cluster_arn" {
  description = "MSK Serverless cluster ARN"
  value       = aws_msk_serverless_cluster.main.arn
}

output "bootstrap_brokers" {
  description = "MSK Serverless bootstrap broker endpoint (IAM/SASL)"
  value       = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
}
