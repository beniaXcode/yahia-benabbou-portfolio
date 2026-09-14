# Zero-Trust GitOps Reference Platform

> **How does code reach production without any human or machine holding a permanent key?**

This is a reference implementation, not a demo app: GitHub OIDC mints short-lived AWS credentials
per job (no IAM access keys anywhere), every container image is signed keylessly with Sigstore and
carries SLSA provenance (no private signing key anywhere), and Kyverno re-verifies that provenance
at admission before a workload ever runs on the cluster.

**Status:** under active build, phase by phase. This README is the Phase 0 placeholder — the full
shop-window version (architecture diagram, headline claims, the copy-pasteable verification
command, honest limits) lands in Phase 8, once there is something real for it to describe. Until
then, start with [`CLAUDE.md`](CLAUDE.md) for how this project is run, and
[`docs/versions.md`](docs/versions.md) for exactly which tool versions are pinned and how they
were resolved.

## Repository map

| Path | Purpose |
|---|---|
| `docs/` | Architecture, threat model, ADRs, runbooks, compliance mapping, the case study |
| `infra/terraform/` | AWS identity foundation: OIDC provider, EKS, ECR, Pod Identity, KMS, Secrets Manager |
| `policies/` | Kyverno policies — the single source of truth for both admission and shift-left CI checks |
| `gitops/` | Argo CD app-of-apps, platform components, and the demo app's Kustomize overlays |
| `apps/demo-api/` | The deliberately small sample workload |
| `demo/` | `kind` cluster bring-up and the six attack scenarios |
| `tools/` | Small scripts backing `make` targets (policy catalog generation, secret checks, diagram rendering) |
| `test/` | End-to-end and fixture-based tests |
| `.claude/` | Claude Code project configuration for working in this repo |

See `CLAUDE.md` for the ten non-negotiable constraints (C1–C10) this repository is judged against.
