locals {
  prefix = "${var.project_name}-${var.environment}"
}

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
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    
    # Configure logs to capture user-data output
    set -e
    exec > /var/log/user-data.log 2>&1

    # Install Java, Kafka, and Python packages
    yum update -y
    yum install -y wget java-17-amazon-corretto-headless python3-pip

    KAFKA_VERSION="4.3.0"
    SCALA_VERSION="2.13"
    cd /opt
    wget -q https://downloads.apache.org/kafka/$${KAFKA_VERSION}/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz
    tar -xzf /opt/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz
    ln -s /opt/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION} /opt/kafka
    echo 'export PATH=$PATH:/opt/kafka/bin' >> /etc/profile.d/kafka.sh

    wget -q https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.7/aws-msk-iam-auth-2.3.7-all.jar \
      -O /opt/kafka/libs/aws-msk-iam-auth-2.3.7-all.jar

    # Create client.properties file for IAM authentication
    echo "security.protocol=SASL_SSL" > /opt/kafka/bin/client.properties
    echo "sasl.mechanism=AWS_MSK_IAM" >> /opt/kafka/bin/client.properties
    echo "sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;" >> /opt/kafka/bin/client.properties
    echo "sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler" >> /opt/kafka/bin/client.properties
    chown ec2-user:ec2-user /opt/kafka/bin/client.properties

    echo "export CLASSPATH=/opt/kafka/libs/aws-msk-iam-auth-2.3.7-all.jar" >> /etc/profile.d/kafka.sh

    pip install kafka-python aws-msk-iam-sasl-signer-python

    /opt/kafka/bin/kafka-topics.sh --create --if-not-exists --topic first_topic --command-config /opt/kafka/bin/client.properties --partitions 1 --bootstrap-server ${var.msk_bootstrap_servers}
    
    echo "user-data completed successfully"

  EOF

  tags = merge(var.common_tags, {
    Name = "${local.prefix}-kafka-client"
  })
}
