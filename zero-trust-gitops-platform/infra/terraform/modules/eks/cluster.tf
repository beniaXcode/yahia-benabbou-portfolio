resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_39:BRIEF.md's design is a private endpoint plus a *restricted* public CIDR allowlist (never 0.0.0.0/0 — allowed_public_cidrs has no default), not a fully disabled public endpoint, so CI/local kubectl access has a documented path
  #checkov:skip=CKV_AWS_38:allowed_public_cidrs is a required variable with no default specifically so it can never silently become 0.0.0.0/0 — see the comment above
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(values(aws_subnet.public)[*].id, values(aws_subnet.private)[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_public_cidrs
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# EKS access entries, not the legacy aws-auth ConfigMap. Keyed by a static
# label (map keys, known at plan time) rather than toset() over the ARNs
# themselves — those ARNs are usually still unknown-until-apply (e.g. a
# role Terraform is creating in the same run), and for_each needs its keys
# known at plan time.
resource "aws_eks_access_entry" "admin" {
  for_each = var.cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = var.cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# Pod Identity: the addon that lets aws_eks_pod_identity_association (in the
# pod-identity module) actually work. No addon_version pinned — AWS's
# compatible-version matrix per addon/cluster-version isn't reachable to
# check from here, and EKS defaults to a supported version on its own.
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}
