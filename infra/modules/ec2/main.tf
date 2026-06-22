locals {
  prefix = "${var.project_name}-${var.environment}"
}

# Current AWS region (used to set AWS_REGION for the Python producer)
data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Key pair from local public key
resource "aws_key_pair" "main" {
  key_name   = "${local.prefix}-key"
  public_key = file(var.public_key_path)

  tags = var.common_tags
}

# Security group — SSH inbound, all outbound (for Kafka + internet)
resource "aws_security_group" "ec2" {
  name        = "${local.prefix}-ec2-sg"
  description = "Kafka client EC2 - SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.prefix}-ec2-sg"
  })
}

# EC2 instance — Kafka producer/consumer client
resource "aws_instance" "kafka_client" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    msk_bootstrap_servers = var.msk_bootstrap_servers
    aws_region            = data.aws_region.current.name
    producer_b64          = base64encode(file("${path.module}/data_generation_kafka_producer.py"))
  })

  # Re-provision the instance when the producer script changes (user_data only
  # runs on first boot, so the script is baked in at launch time).
  user_data_replace_on_change = true

  tags = merge(var.common_tags, {
    Name = "${local.prefix}-kafka-client"
  })
}
