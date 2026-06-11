output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.kafka_client.id
}

output "public_ip" {
  description = "Public IP to SSH into the instance"
  value       = aws_instance.kafka_client.public_ip
}
