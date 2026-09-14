# 0004. External Secrets Operator + AWS Secrets Manager over Sealed Secrets or SOPS

Status: Accepted

## Context

C7 requires that a secret never lives in Git, sealed or otherwise. Two common GitOps-compatible
alternatives exist: Sealed Secrets (encrypts a Secret's contents so the ciphertext is safe to
commit, decrypted in-cluster by a controller holding the corresponding private key) and SOPS
(encrypts specific fields of a manifest with a KMS-backed key, decrypted at apply time). Both let a
secret's *encrypted* form live in Git.

## Decision

Runtime secrets are never committed in any form, encrypted or not. External Secrets Operator's
`ClusterSecretStore`/`ExternalSecret` objects (`gitops/platform/external-secrets/`,
`gitops/apps/demo-api/base/externalsecret.yaml`) describe *where* a secret's value lives — AWS
Secrets Manager, via EKS Pod Identity, in production — and ESO fetches the actual value directly
into a Kubernetes Secret at runtime. Git holds no version of the secret at all, encrypted or
otherwise.

## Consequences

A Git history leak (a misconfigured public repo, a forked clone, a compromised CI cache) can never
expose a secret's ciphertext, because there is no ciphertext to expose — the strictly stronger
guarantee C7 asks for over Sealed Secrets/SOPS, both of which still commit *something*
secret-derived. The cost: secret rotation, access control, and audit logging all now live in AWS
Secrets Manager's own control plane rather than in Git — a real dependency on an external system's
availability and correctness, and one more system (ESO itself) whose own compromise would matter.
`gitops/platform/external-secrets/manifests/cluster-secret-store.yaml` also defines a
`local-demo` substitute backend for `make demo`'s kind cluster, which has no AWS account behind
it — see `docs/fidelity.md` for what that substitute does and does not prove.
