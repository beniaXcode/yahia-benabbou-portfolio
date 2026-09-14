# Bootstrap-only: this module has to be applied once, by hand, with local
# state, before any other module's state can move to the S3 backend it
# creates here. It is deliberately not wired into envs/*, which instead
# declare `backend "s3" { ... }` pointing at what this module produced.

# Access logging, cross-region replication, and event notifications are all
# reasonable asks for a production state bucket, but each needs its own
# extra infrastructure (a logging bucket, a replica bucket in a second
# region, an SNS/Lambda target) that's disproportionate to what this
# reference platform's Phase 2 scope covers. Versioning + KMS encryption +
# a full public-access block (below) are the controls that actually matter
# for a low-traffic state bucket; the rest is a real gap, not an oversight.
resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:no access-log bucket in this reference platform's scope — see comment above
  #checkov:skip=CKV2_AWS_62:no event-notification target in this reference platform's scope — see comment above
  #checkov:skip=CKV_AWS_144:no cross-region replica in this reference platform's scope — see comment above
  bucket = var.bucket_name

  # Guards against `terraform destroy` deleting a bucket that still holds
  # every environment's state.
  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}
