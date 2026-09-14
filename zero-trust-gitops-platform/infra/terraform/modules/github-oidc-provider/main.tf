# IAM OIDC provider for GitHub Actions. No thumbprint_list: this attribute
# is Optional+Computed on the AWS provider version pinned here, and GitHub's
# own current guidance is not to hardcode it since the certificate (and
# therefore its thumbprint) rotates independently of this configuration.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = [var.oidc_audience]

  tags = var.tags
}

# Trust/permission policies are built with plain jsonencode() rather than
# the aws_iam_policy_document data source on purpose: that data source is
# itself implemented inside the AWS provider, so under `mock_provider` in
# terraform test it gets mocked away instead of actually computing JSON —
# jsonencode() is a Terraform-core function and always evaluates for real,
# in both `plan` and `test`, which is what tests/github_oidc_provider.tftest.hcl
# relies on to assert the exact trust-policy shape (C6).

# --- build role: trusted for exactly one ref, used to push images ----------

resource "aws_iam_role" "build" {
  name = "gh-oidc-build-${var.github_repo}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = var.oidc_audience
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:${var.build_ref}"
        }
      }
    }]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}

# ecr:GetAuthorizationToken has no resource ARN to scope to (AWS requires
# "*" for this specific action) — the actual repo-level push scoping lives
# in the ECR module's repository policy, not here.
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

# --- deploy roles: one per GitHub Environment, each pinned exactly --------

resource "aws_iam_role" "deploy" {
  for_each = toset(var.deploy_environments)

  name = "gh-oidc-deploy-${var.github_repo}-${each.value}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = var.oidc_audience
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:${each.value}"
        }
      }
    }]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}
