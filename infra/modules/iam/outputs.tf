output "ec2_instance_profile_name" {
  description = "Instance profile name to attach to the Kafka client EC2"
  value       = aws_iam_instance_profile.ec2_msk.name
}
