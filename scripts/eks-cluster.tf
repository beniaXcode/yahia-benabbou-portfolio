# Representative Terraform for the EKS cluster and supporting resources — illustrative of the
# pattern used to support staging-to-production promotion, not the literal product's config.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

variable "environment" {
  type        = string
  description = "staging or production"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "saas-platform-${var.environment}"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size       = var.environment == "production" ? 2 : 1
      max_size       = var.environment == "production" ? 6 : 2
      desired_size   = var.environment == "production" ? 3 : 1
      instance_types = ["t3.large"]
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "saas-platform-${var.environment}"
  cidr    = "10.30.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.30.1.0/24", "10.30.2.0/24"]
  public_subnets  = ["10.30.101.0/24", "10.30.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"
}

resource "aws_db_instance" "app_db" {
  identifier             = "saas-platform-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.environment == "production" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  multi_az               = var.environment == "production"
  skip_final_snapshot    = var.environment != "production"
}
