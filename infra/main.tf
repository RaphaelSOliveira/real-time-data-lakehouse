/*
main.tf — The root module. Connects all the other modules together. Think of it as the orchestrator.
Also Defines locals (computed values reused across modules like prefix and common_tags).
This is always a standalone file so root module logic doesn't get mixed with module logic 
*/

locals {
  prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  common_tags         = local.common_tags
}

module "msk" {
  source = "./modules/msk"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.networking.msk_security_group_id]
  common_tags        = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name    = var.project_name
  environment     = var.environment
  msk_cluster_arn = module.msk.cluster_arn
  common_tags     = local.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  subnet_id             = module.networking.public_subnet_ids[0]
  instance_profile_name = module.iam.ec2_instance_profile_name
  msk_bootstrap_servers = module.msk.bootstrap_brokers
  common_tags           = local.common_tags
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = "ridestream-production"
  common_tags  = local.common_tags
}
