output "cluster_arn" {
  description = "MSK Serverless cluster ARN"
  value       = aws_msk_serverless_cluster.main.arn
}

output "bootstrap_brokers" {
  description = "MSK Serverless bootstrap broker endpoint"
  value       = aws_msk_serverless_cluster.main.cluster_name
}
