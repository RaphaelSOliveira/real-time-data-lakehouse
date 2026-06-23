locals {
  prefix = "${var.project_name}-${var.environment}"

  # Derive the MSK topic/group resource ARNs from the cluster ARN, e.g.
  # arn:...:cluster/name/uuid  ->  arn:...:topic/name/uuid/<topic>
  topic_arn = "${replace(var.msk_cluster_arn, ":cluster/", ":topic/")}/${var.topic_name}"
  group_arn = "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*"
}

# CloudWatch log group/stream for Firehose delivery errors.
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.delivery_stream_name}"
  retention_in_days = 14
  tags              = var.common_tags
}

resource "aws_cloudwatch_log_stream" "s3_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

# IAM role Firehose assumes to read from MSK and write to S3.
resource "aws_iam_role" "firehose" {
  name = "${local.prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${local.prefix}-firehose-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MSKClusterAccess"
        Effect = "Allow"
        Action = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2"
        ]
        Resource = var.msk_cluster_arn
      },
      {
        Sid    = "MSKTopicRead"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeTopicDynamicConfiguration",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = [
          var.msk_cluster_arn,
          local.topic_arn,
          local.group_arn
        ]
      },
      {
        Sid    = "S3RawDelivery"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose.arn}:*"
      }
    ]
  })
}

# Resource-based policy on the MSK cluster authorizing the Firehose service to
# set up private (PrivateLink) connectivity. Without this, stream creation fails
# with CREATE_PRIVATE_LINK_FAILED / not authorized for kafka:CreateVpcConnection.
resource "aws_msk_cluster_policy" "firehose" {
  cluster_arn = var.msk_cluster_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "FirehoseMSKSourceAccess"
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action = [
        "kafka:CreateVpcConnection",
        "kafka:GetBootstrapBrokers",
        "kafka:DescribeClusterV2"
      ]
      Resource = var.msk_cluster_arn
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.delivery_stream_name
  destination = "extended_s3"

  # The cluster policy must exist before Firehose attempts the PrivateLink setup.
  depends_on = [aws_msk_cluster_policy.firehose]

  # Source: Amazon MSK topic. read_from_timestamp is intentionally omitted so
  # Firehose starts reading from the stream creation time (the AWS default).
  # Set it to "1970-01-01T00:00:00Z" instead to read from the earliest offset.
  msk_source_configuration {
    msk_cluster_arn = var.msk_cluster_arn
    topic_name      = var.topic_name

    authentication_configuration {
      connectivity = "PRIVATE"
      role_arn     = aws_iam_role.firehose.arn
    }
  }

  # Destination: raw events landed in S3, partitioned by event arrival time.
  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = var.s3_bucket_arn
    buffering_size      = var.buffering_size
    buffering_interval  = var.buffering_interval
    compression_format  = "GZIP"
    prefix              = "raw/${var.topic_name}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/${var.topic_name}/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.s3_delivery.name
    }
  }

  tags = merge(var.common_tags, {
    Name = var.delivery_stream_name
  })
}
