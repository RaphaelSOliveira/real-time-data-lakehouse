locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_msk_serverless_cluster" "main" {
  cluster_name = "${local.prefix}-msk"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.prefix}-msk"
  })
}
