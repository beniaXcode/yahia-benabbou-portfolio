# Deliberately violates require-s3-public-access-block.rego: a bucket with
# no aws_s3_bucket_public_access_block anywhere in the plan.
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

resource "aws_s3_bucket" "bad" {
  bucket = "fixture-bad-open-bucket"
}
