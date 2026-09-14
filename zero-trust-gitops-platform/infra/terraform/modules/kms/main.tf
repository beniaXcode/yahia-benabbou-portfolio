resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  # Explicit rather than relying on AWS's implicit default key policy:
  # the account root gets full administrative access over the key (the
  # standard, AWS-recommended baseline — without it, an account could
  # permanently lock itself out of its own key), and everything else is
  # granted per-resource via the IAM policies this platform's other
  # modules attach to specific roles, not through this key policy.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountRootFullAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}
