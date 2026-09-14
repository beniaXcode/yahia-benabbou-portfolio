# 0005. EKS Pod Identity over IRSA

Status: Accepted

## Context

A running workload needs its own scoped AWS permissions, never the EC2 node's own instance role.
Two EKS-native mechanisms provide this: IAM Roles for Service Accounts (IRSA), which annotates a
Kubernetes ServiceAccount with a role ARN and relies on an OIDC identity provider plus a trust
policy condition matching the ServiceAccount's namespace/name; and EKS Pod Identity, a newer,
purpose-built mechanism where an `EKS Pod Identity Association` binds a ServiceAccount to a role
directly, without the cluster needing its own OIDC provider for this purpose.

## Decision

`infra/terraform/modules/pod-identity` uses EKS Pod Identity as the primary mechanism: one
`aws_iam_role` per association, trusted only by `pods.eks.amazonaws.com`
(`sts:AssumeRole`+`sts:TagSession`), bound to a namespace/ServiceAccount pair via
`aws_eks_pod_identity_association`. IRSA remains documented as the alternative a real deployment
targeting an older EKS version (Pod Identity requires a supported add-on and a sufficiently recent
cluster) would fall back to.

## Consequences

Pod Identity's trust condition is simpler to audit (one fixed service principal, not a
per-cluster OIDC provider URL plus a namespace/ServiceAccount string match that's easy to get
subtly wrong) and requires no separate `aws_iam_openid_connect_provider` for cluster workloads
distinct from the one already created for GitHub Actions
(`infra/terraform/modules/github-oidc-provider`). The cost: Pod Identity is the newer mechanism,
requires the `eks-pod-identity-agent` addon (`infra/terraform/modules/eks`) running on every node,
and is less universally documented in older third-party tooling that still assumes IRSA — a real
deployment on an EKS version predating Pod Identity support has no choice but IRSA, which is why
this repository documents it as the alternative rather than omitting it.
