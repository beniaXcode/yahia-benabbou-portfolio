output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "build_role_arn" {
  value = module.oidc.build_role_arn
}

output "deploy_role_arns" {
  value = module.oidc.deploy_role_arns
}
