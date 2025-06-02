locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment       = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  project_name      = var.project_name
  environment      = var.environment
  cluster_version  = var.eks_cluster_version
  
  vpc_id           = module.vpc.vpc_id
  private_subnets  = module.vpc.private_subnets
  public_subnets   = module.vpc.public_subnets
  
  node_groups = {
    main = {
      instance_types = var.eks_node_instance_types
      scaling_config = {
        desired_size = 2
        max_size     = 5
        min_size     = 1
      }
    }
  }
  
  tags = local.common_tags
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment       = var.environment
  
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  db_name           = var.db_name
  db_username       = var.db_username
  
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  
  tags = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment = var.environment
  
  cluster_name = module.eks.cluster_name
  
  tags = local.common_tags
}