# Deliberately violates no-static-aws-keys.rego (C2): a static credential.
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

resource "aws_iam_user" "bad" {
  name = "fixture-bad-user"
}

resource "aws_iam_access_key" "bad" {
  user = aws_iam_user.bad.name
}
