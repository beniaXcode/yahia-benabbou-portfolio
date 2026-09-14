# 0001. GHCR over ECR for this specific deployment

Status: Accepted

## Context

BRIEF.md's fixed technology choices name AWS ECR as the production image registry, matching
`infra/terraform/modules/ecr`'s access-controlled repository policy (push scoped to the `build`
OIDC role, pull scoped to a separate `pull_role_arn`). This repository's own Phase 2 Terraform was
written against that design and validated (`terraform validate`/`plan`/`test`, `conftest`) — but it
has never been `terraform apply`d, because no AWS account exists behind this specific GitHub
repository. `build-sign-attest.yml` still needs somewhere real to push to, on every real run once
this branch reaches GitHub.

## Decision

`build-sign-attest.yml` pushes to `ghcr.io/beniaxcode/yahia-benabbou-portfolio/demo-api`,
authenticating with the workflow's own ambient `GITHUB_TOKEN` — itself OIDC-derived, so this
doesn't reintroduce a static credential or violate C1. `infra/terraform/modules/ecr` remains
committed, tested, and documented as the production target a real AWS-backed deployment of this
platform would use instead.

## Consequences

This deployment's registry-scoped IAM push/pull separation (the actual point of
`modules/ecr`'s repository policy) is not exercised end-to-end here — GHCR's package permissions
model is different and simpler. `policies/supply-chain/allowed-registries.yaml` and the three
`verifyImages` policies accept both the ECR pattern and this GHCR namespace for exactly this
reason, so switching a real deployment back to ECR is a one-line change to `REGISTRY`/`IMAGE_NAME`
in the workflow and no change to any policy. The tradeoff: a reviewer checking out this repository
and reading `infra/terraform/modules/ecr` sees a control that isn't the one actually protecting the
image this specific instance runs — `docs/fidelity.md` says so plainly rather than leaving that
gap for a reviewer to discover on their own.
