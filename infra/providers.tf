/* 
providers.tf - Declares Terraform itself and the AWS provider.  
Terraform needs to know which cloud SDK to download (hashicorp/aws ~> 5.0) and which region to deploy into. 
This is always a standalone file so provider config doesn't get mixed with resource logic
*/

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
