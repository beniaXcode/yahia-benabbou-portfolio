# Deliberately violates require-encryption.rego: no kms_key_id at all
# (not even a reference to one being created — genuinely absent).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.64.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

resource "aws_secretsmanager_secret" "bad" {
  name = "fixture-bad-secret"
}
