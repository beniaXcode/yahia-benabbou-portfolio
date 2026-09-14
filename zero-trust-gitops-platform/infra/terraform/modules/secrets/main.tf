# C7: this module provisions the secret *container* only. No
# aws_secretsmanager_secret_version is ever created here — the value is
# written by External Secrets Operator's counterpart (or by hand, once,
# out of band) at runtime, never by Terraform, and therefore never lives
# in this Git repository in any form, sealed or otherwise.
resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_policy" "this" {
  secret_arn = aws_secretsmanager_secret.this.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowReadFromRuntimeRoles"
      Effect    = "Allow"
      Principal = { AWS = var.reader_role_arns }
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation_lambda_arn == null ? 0 : 1

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}
