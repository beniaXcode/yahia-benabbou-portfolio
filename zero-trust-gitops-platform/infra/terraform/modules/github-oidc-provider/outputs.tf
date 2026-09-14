output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "build_role_arn" {
  value = aws_iam_role.build.arn
}

output "build_role_name" {
  value = aws_iam_role.build.name
}

output "deploy_role_arns" {
  description = "Map of GitHub Environment name -> deploy role ARN."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}
