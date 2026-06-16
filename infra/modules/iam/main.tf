locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_iam_role" "ec2_msk" {
  name = "${local.prefix}-ec2-msk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "ec2_msk" {
  name = "${local.prefix}-ec2-msk-policy"
  role = aws_iam_role.ec2_msk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kafka-cluster:Connect",
        "kafka-cluster:DescribeCluster",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:CreateTopic",
        "kafka-cluster:DescribeTopic",
        "kafka-cluster:AlterTopic",
        "kafka-cluster:DeleteTopic",
        "kafka-cluster:ReadData",
        "kafka-cluster:WriteData",
        "kafka-cluster:DescribeGroup",
        "kafka-cluster:AlterGroup"
      ]
      Resource = [
        var.msk_cluster_arn,
        replace(var.msk_cluster_arn, ":cluster/", ":topic/"),
        "${replace(var.msk_cluster_arn, ":cluster/", ":topic/")}/*",
        replace(var.msk_cluster_arn, ":cluster/", ":group/"),
        "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_msk" {
  name = "${local.prefix}-ec2-msk-profile"
  role = aws_iam_role.ec2_msk.name
}
