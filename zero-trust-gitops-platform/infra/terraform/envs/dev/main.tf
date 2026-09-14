locals {
  cluster_name = "ztgp-dev"

  common_tags = {
    Project     = "zero-trust-gitops-platform"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source      = "../../modules/kms"
  alias       = "zero-trust-gitops-platform-dev"
  description = "Shared key for zero-trust-gitops-platform's dev environment (ECR, Secrets Manager, EKS)"
  account_id  = var.account_id
  tags        = local.common_tags
}

module "oidc" {
  source              = "../../modules/github-oidc-provider"
  github_org          = var.github_org
  github_repo         = var.github_repo
  deploy_environments = var.deploy_environments
  tags                = local.common_tags
}

module "eks" {
  source                       = "../../modules/eks"
  cluster_name                 = local.cluster_name
  kubernetes_version           = var.kubernetes_version
  kms_key_arn                  = module.kms.key_arn
  availability_zones           = var.availability_zones
  allowed_public_cidrs         = var.allowed_public_cidrs
  cluster_admin_principal_arns = module.oidc.deploy_role_arns
  tags                         = local.common_tags
}

module "ecr" {
  source         = "../../modules/ecr"
  name           = "zero-trust-gitops-platform/demo-api"
  kms_key_arn    = module.kms.key_arn
  build_role_arn = module.oidc.build_role_arn
  # The node role pulls images (kubelet's containerd credential helper) —
  # not the pod-identity role below, which is for the application's own
  # AWS API calls at runtime, a separate concern.
  pull_role_arns = [module.eks.node_role_arn]
  tags           = local.common_tags
}

module "demo_api_secret" {
  source           = "../../modules/secrets"
  name             = "zero-trust-gitops-platform/demo-api-db"
  kms_key_arn      = module.kms.key_arn
  reader_role_arns = [module.demo_api_pod_identity.role_arn]
  tags             = local.common_tags
}

module "demo_api_pod_identity" {
  source          = "../../modules/pod-identity"
  workload_name   = "demo-api"
  cluster_name    = module.eks.cluster_name
  namespace       = "demo-api"
  service_account = "demo-api"

  # Built from the predictable ARN pattern (with the "-*" suffix AWS's
  # random suffix requires) rather than module.demo_api_secret.secret_arn:
  # that module's own reader_role_arns already depends on this role's ARN,
  # so referencing the secret's output here too would be a real dependency
  # cycle between the two modules.
  permissions_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:zero-trust-gitops-platform/demo-api-db-*"
    }]
  })

  tags = local.common_tags
}
