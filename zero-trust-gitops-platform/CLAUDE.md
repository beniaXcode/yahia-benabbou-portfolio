# Operating manual — zero-trust-gitops-platform

**What this is, in two sentences.** A reference GitOps platform on AWS/EKS proving that code can
reach production with no long-lived credential anywhere — GitHub OIDC → short-lived AWS STS,
Sigstore keyless signing, SLSA provenance, Kyverno admission verification. The one question every
file here must serve: *how does code reach production without anyone holding a permanent key?*

## Commands — always via `make`, run from this directory

| Command | Does |
|---|---|
| `make help` | List every target |
| `make tools` | Install pinned CLIs (`mise install`, or a `go install` fallback) |
| `make lint` | pre-commit: fmt, yamllint, gitleaks, the secret guard |
| `make build` / `make test` / `make image` | demo-api Go binary, tests, container image |
| `make policy-catalog` | Regenerate `docs/policy-catalog.md` from `policies/` annotations |
| `make diagrams` | Render `docs/diagrams/src/*.mmd` to SVG |
| `make docs` | `mkdocs build --strict` |
| `make verify-chain DIGEST=...` | cosign verify + verify-attestation + Rekor lookup |
| `make demo` / `make demo-attack` | Full kind GitOps loop; the six attack scenarios |
| `make verify` | Every gate this repo claims to pass, chained |

Never document a raw `terraform`/`kubectl`/`cosign` invocation in prose that `make` already wraps.

## The ten constraints — if a change would violate any of these, stop and ask; do not work around it

- **C1** Zero GitHub Actions secrets besides `GITHUB_TOKEN` — OIDC only.
- **C2** No `aws_iam_access_key` anywhere in Terraform — Pod Identity / IRSA only.
- **C3** No private signing key — Sigstore keyless (Fulcio + Rekor) only.
- **C4** Kyverno blocks any image whose signature/provenance doesn't match the expected workflow identity.
- **C5** Digest-pinned images only — no `:latest`, no mutable tags, anywhere deployed.
- **C6** Every IAM trust policy pins `sub` to an exact repo+ref/environment and `aud` to `sts.amazonaws.com` — never a wildcard.
- **C7** Secrets never live in git, sealed or otherwise — ESO + Secrets Manager at runtime.
- **C8** The same Kyverno policies run in CI (shift-left) and at admission — one source of truth.
- **C9** Every namespace starts default-deny; allowances are explicit.
- **C10** `make demo` reproduces the loop in ≤15 minutes, offline-capable, no AWS account.

Where the local `kind` demo cannot faithfully reproduce cloud behaviour, say so in
`docs/fidelity.md` — never fake it silently.

## Conventions

- Conventional Commits. One phase, one commit (or a short series), each with a passing gate.
- An ADR (`docs/adr/NNNN-*.md`) is required for any new dependency or architectural decision.
- Every Kyverno policy ships with both a passing and a failing `kyverno-test.yaml` fixture.
- Every GitHub Action is pinned to a commit SHA (version in a trailing comment), never a tag.
- Every deployed manifest references images by digest, never by tag.
- Write the doc/runbook with the code that needs it, not after.

## Directory map

`docs/` architecture, threat model, ADRs, runbooks, compliance mapping, case study · `infra/terraform/`
AWS identity, EKS, ECR, KMS, Secrets Manager · `policies/` Kyverno, single source of truth for
admission and shift-left · `gitops/` Argo CD app-of-apps + overlays · `apps/demo-api/` the sample
workload · `demo/` kind bring-up + attack scripts · `tools/` scripts backing `make` targets ·
`test/` e2e and fixtures · `.claude/` this project's Claude Code configuration.

## Hard prohibitions

Never commit anything matching `*.key`, `*.pem`, `.env`, `kubeconfig`, `AKIA*`. Never add a GitHub
Actions secret. Never run `terraform apply` against a real AWS account without explicit
confirmation first. Never `kubectl delete` outside the `kind` demo context. Never weaken a policy,
skip a test, or relax a fixture to make a check pass — fix the input, or stop and ask.

## Pre-flight for risky operations

Before any `terraform apply`, `gh api -X PATCH/DELETE`, `gh repo delete`, or cluster-scoped delete:
print the exact command and wait for explicit confirmation. This sandbox currently has no AWS
account and no reachable Docker daemon — see `docs/fidelity.md` and the Phase 0 report for what
that means for which gates can actually be run here versus asserted.

## Style

YAML: 2-space indent, no tabs. Go: `gofmt`. Terraform: `terraform fmt`. Markdown in `docs/adr/`:
one sentence per line. No `TODO`/`TBD`/`FIXME`/lorem-ipsum in committed work — CI checks for this.
