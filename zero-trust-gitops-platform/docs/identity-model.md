# Identity model

Every identity in this platform is short-lived, scoped to one purpose, and minted by exchanging
one token for another — never a static credential issued once and reused indefinitely.

## GitHub Actions → AWS (build-time)

```
GitHub OIDC token (per job, minutes-lived)
  claims: sub=repo:beniaXcode/yahia-benabbou-portfolio:ref:refs/heads/main (or :environment:<env>)
          aud=sts.amazonaws.com
  → AWS STS AssumeRoleWithWebIdentity
  → 15-minute session, scoped to one IAM role
```

The trust relationship lives entirely in Terraform, not in any GitHub secret:
[`infra/terraform/modules/github-oidc-provider`](https://github.com/beniaXcode/yahia-benabbou-portfolio/tree/main/zero-trust-gitops-platform/infra/terraform/modules/github-oidc-provider)
creates `token.actions.githubusercontent.com` as an OIDC identity provider and two roles:

- **`build`** — trusted only for `repo:<org>/<repo>:ref:refs/heads/main`. This is the role
  `build-sign-attest.yml` assumes to push to ECR.
- **`deploy`** — trusted only for `repo:<org>/<repo>:environment:<env>`. Reserved for a future
  workflow that needs to act against a specific GitHub Environment rather than a branch.

Both conditions require `aud = sts.amazonaws.com` and reject a bare or wildcarded `sub` (C6) — this
is what `infra/terraform/tests/github_oidc_provider.tftest.hcl` asserts with Terraform's native
test framework, and what `infra/terraform/policy/`'s conftest rules deny at plan time if anyone
tries to loosen it (with a fail fixture proving the guard actually rejects a wildcard `sub`).

**Why this is safe to publish.** The role ARN itself is not a secret — the environments in Phase 9
carry it as a plain variable, not a secret, and the README says so explicitly. Knowing a role's ARN
grants nothing; the trust policy's `sub`/`aud` conditions are what actually gate who can assume it,
and those are enforced by AWS, not by keeping the ARN hidden.

## GitHub Actions → Sigstore (signing identity)

The same OIDC token used for AWS is presented to Fulcio, which issues a short-lived X.509
certificate binding the token's identity (the workflow, ref, and repository) to a signing key
generated for that one operation and discarded immediately after. Kyverno's admission-time
verification checks that certificate's `subject`/`issuer` fields, not "is this signed by *someone*"
— see [ADR-0003](adr/0003-sigstore-keyless-signing.md) and
[`supply-chain.md`](supply-chain.md).

## EKS Pod Identity (runtime)

```
Pod's ServiceAccount
  → EKS Pod Identity association (infra/terraform/modules/pod-identity)
  → sts:AssumeRole + sts:TagSession, trusted only for pods.eks.amazonaws.com
  → session scoped to exactly the IAM policy this workload's association grants
```

No workload inherits the EC2 node's own instance role — `modules/pod-identity` creates one
`aws_iam_role` per association, trusted only by the Pod Identity service principal, with whatever
permissions policy the caller supplies (in this repo, `infra/terraform/envs/dev` wires it up per
workload; `demo-api` itself has none today, since it makes no AWS calls — see
`gitops/apps/demo-api/base/deployment.yaml`'s comment on `automountServiceAccountToken: false`).
[ADR-0005](adr/0005-eks-pod-identity-over-irsa.md) records why Pod Identity was chosen over IRSA.

## Argo CD (in-cluster identity)

Argo CD's own admin account is disabled (`gitops/platform/argocd/values.yaml`); `role:readonly` is
the RBAC default for anyone authenticated with no more specific rule. An OIDC SSO stanza is
documented in that same values file — illustrative, since this repository has no real identity
provider to test against — with a local-only fallback (`kubectl exec`/`port-forward`, never a
checked-in password) recorded honestly in [`fidelity.md`](fidelity.md).

## What never appears anywhere in this repository

- A static AWS access key or secret key (C2) — [`tools/check-no-secrets.sh`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/tools/check-no-secrets.sh)
  and `.gitleaks.toml` both check for this on every commit.
- A cosign private key (C3) — signing is keyless in production; the local demo's ephemeral key pair
  is generated fresh at `make demo` time and never written to disk outside a `mktemp -d` that gets
  deleted before the script exits (`demo/up.sh`).
- A GitHub Actions secret other than the ambient `GITHUB_TOKEN` (C1) — enforced by
  `tools/check-no-secrets.sh` and `.github/workflows/verify-no-secrets.yml`.
