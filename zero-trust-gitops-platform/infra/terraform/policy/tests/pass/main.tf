# Small, literal-valued fixture (deliberately not the real modules): every
# attribute here is a plain string, not a reference to another resource
# being created in the same plan, specifically so nothing is "known after
# apply" — that would hide a real violation from conftest, as it did once
# during Phase 2 (see docs/fidelity.md). This is what a compliant version
# of each of the five checks in ../../*.rego looks like.
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

# no-static-aws-keys.rego: compliant by omission — no aws_iam_access_key
# resource anywhere in this fixture.

# github-oidc-exact-subject.rego: exact ref, exact aud, no wildcard.
resource "aws_iam_role" "build" {
  name = "fixture-build"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:beniaXcode/yahia-benabbou-portfolio:ref:refs/heads/main"
        }
      }
    }]
  })
}

# no-wildcard-iam-actions.rego: exact action, no "*".
resource "aws_iam_role_policy" "build_ecr_auth" {
  name = "ecr-get-authorization-token"
  role = aws_iam_role.build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ecr:GetAuthorizationToken"
      Resource = "*"
    }]
  })
}

# require-encryption.rego: literal (known) KMS key ID, not a reference.
resource "aws_secretsmanager_secret" "demo" {
  name       = "fixture-secret"
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
}

resource "aws_ecr_repository" "demo" {
  name = "fixture-repo"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = "arn:aws:kms:us-east-1:123456789012:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }
}

resource "aws_s3_bucket" "demo" {
  bucket = "fixture-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# require-s3-public-access-block.rego: all four flags true.
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket                  = aws_s3_bucket.demo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
