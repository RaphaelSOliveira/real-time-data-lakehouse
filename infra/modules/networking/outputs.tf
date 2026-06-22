output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (used by MSK)"
  value       = aws_subnet.public[*].id
}

output "msk_security_group_id" {
  description = "Security group ID for MSK brokers"
  value       = aws_security_group.msk.id
}
