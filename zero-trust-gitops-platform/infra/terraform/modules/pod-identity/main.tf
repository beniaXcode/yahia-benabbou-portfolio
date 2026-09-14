# EKS Pod Identity's own trust relationship — distinct from the OIDC
# federation trust used for GitHub Actions. Pods never see this role's
# credentials directly; the Pod Identity agent (the addon created in the
# eks module) exchanges the pod's ServiceAccount token for these
# credentials on the node, scoped to exactly this association.
resource "aws_iam_role" "this" {
  name = "pod-identity-${var.workload_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Principal = { Service = "pods.eks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.workload_name}-permissions"
  role   = aws_iam_role.this.id
  policy = var.permissions_policy_json
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn

  tags = var.tags
}
