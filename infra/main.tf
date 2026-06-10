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
