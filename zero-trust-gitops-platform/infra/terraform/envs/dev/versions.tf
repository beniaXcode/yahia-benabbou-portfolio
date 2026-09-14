terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.64.0, < 7.0.0"
    }
  }

  # Bootstrapped once, by hand, via infra/terraform/modules/tfstate-backend
  # (see that module's main.tf). Backend blocks can't reference variables,
  # so these names are hardcoded to match whatever that bootstrap actually
  # created — update them here if you name yours differently.
  backend "s3" {
    bucket         = "zero-trust-gitops-platform-tfstate"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "zero-trust-gitops-platform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
