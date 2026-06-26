locals {
  prefix = "${var.project_name}-${var.environment}"

  job_name = "${local.prefix}-riskops-transform"

  # Raw source and refined target prefixes within the lakehouse bucket.
  source_path = "s3://${var.bucket_name}/raw/${var.topic_name}/"
  target_path = "s3://${var.bucket_name}/refined/${var.topic_name}/"

  # Where the PySpark script and Glue's temp/spark-logs live in the bucket.
  script_key      = "scripts/riskops_transform.py"
  script_location = "s3://${var.bucket_name}/${local.script_key}"
  temp_dir        = "s3://${var.bucket_name}/glue/tmp/"
  spark_logs_dir  = "s3://${var.bucket_name}/glue/spark-logs/"
}

# Upload the transformation script to S3. The etag makes Terraform re-upload
# whenever the file changes, so the job always runs the latest logic.
resource "aws_s3_object" "etl_script" {
  bucket = var.bucket_name
  key    = local.script_key
  source = "${path.module}/glue_scripts/riskops_transform.py"
  etag   = filemd5("${path.module}/glue_scripts/riskops_transform.py")

  tags = var.common_tags
}

# IAM role Glue assumes to run the job.
resource "aws_iam_role" "glue" {
  name = "${local.prefix}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# Baseline Glue permissions (CloudWatch Logs, etc.).
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Scoped S3 access: read raw + script, write refined + Glue temp/logs.
resource "aws_iam_role_policy" "glue_s3" {
  name = "${local.prefix}-glue-s3-policy"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.bucket_arn
      },
      {
        Sid    = "ReadRawAndScript"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${var.bucket_arn}/raw/${var.topic_name}/*",
          "${var.bucket_arn}/${local.script_key}",
        ]
      },
      {
        Sid    = "WriteRefinedAndGlueScratch"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "${var.bucket_arn}/refined/${var.topic_name}/*",
          "${var.bucket_arn}/glue/*",
        ]
      }
    ]
  })
}

resource "aws_glue_job" "riskops_transform" {
  name              = local.job_name
  role_arn          = aws_iam_role.glue.arn
  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.timeout_minutes

  command {
    name            = "glueetl"
    script_location = local.script_location
    python_version  = "3"
  }

  default_arguments = {
    "--JOB_NAME"                         = local.job_name
    "--source_path"                      = local.source_path
    "--target_path"                      = local.target_path
    "--TempDir"                          = local.temp_dir
    "--job-language"                     = "python"
    "--enable-job-bookmark-option"       = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = local.spark_logs_dir
  }

  # The script object must exist before the job references it.
  depends_on = [aws_s3_object.etl_script]

  tags = merge(var.common_tags, {
    Name = local.job_name
  })
}
