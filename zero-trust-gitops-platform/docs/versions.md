# Resolved tool and dependency versions

Per Operating Rule 4 (never guess a version), every entry below was resolved
from an authoritative source at the date shown, not recalled from memory.
This file is living documentation: a later phase that introduces a new
dependency re-resolves its version at that point and adds a row here — it is
not a one-time snapshot.

## Resolution method used in this sandbox

This session has no direct access to `github.com`/`api.github.com` for
arbitrary repositories (network egress here is policy-scoped to this
session's own repo) and no access to `registry.terraform.io` or
`formulae.brew.sh`. Two allow-listed, unauthenticated sources were used
instead, both of which mirror the real upstream release tag:

- **Go module proxy** (`proxy.golang.org`, directly reachable): for any tool
  that ships a Go `module` path matching its release-tag scheme (verified by
  checking the module adopts [Semantic Import
  Versioning](https://go.dev/ref/mod#major-version-suffixes) — i.e. a `/v2`+
  suffix in the import path once the project passed v1), `go list -m
  <module>@latest` returns the real latest published tag. Verified command
  shown per row.
- **PyPI JSON API** (`pypi.org`, directly reachable): `curl
  https://pypi.org/pypi/<package>/json | jq .info.version` for pure-Python
  tools.
- **Docker Registry HTTP API v2** (`registry-1.docker.io`, `gcr.io` — both
  reachable, unlike `registry.terraform.io`): an anonymous pull token
  (`GET /v2/token?service=...&scope=repository:<repo>:pull`) followed by a
  `HEAD` on `/v2/<repo>/manifests/<tag>` with an OCI-index/manifest-list
  `Accept` header returns the real `Docker-Content-Digest` for a base image
  — used for `apps/demo-api/Dockerfile`'s two `FROM` lines (see below).

Where neither source is reliable (see "Deferred" below), the version is
resolved in the phase that first consumes it, against a reachable source at
that time, rather than guessed now.

## Platform / cluster tooling

| Tool | Version | Resolved via | Date |
|---|---|---|---|
| Argo CD | v3.5.3 | `go list -m github.com/argoproj/argo-cd/v3@latest` | 2026-09-14 |
| Kyverno (+ kyverno-cli, same repo/tag) | v1.19.1 | `go list -m github.com/kyverno/kyverno@latest` | 2026-09-14 |
| Kyverno Chainsaw | v0.2.15 | `go list -m github.com/kyverno/chainsaw@latest` | 2026-09-14 |
| Policy Reporter | v1.10.3 | `go list -m github.com/kyverno/policy-reporter@latest` | 2026-09-14 |
| External Secrets Operator | v1.3.2 | `go list -m github.com/external-secrets/external-secrets@latest` | 2026-09-14 |
| cosign | v2.6.5 | `go list -m github.com/sigstore/cosign/v2@latest` | 2026-09-14 |
| syft | v1.51.1 | `go list -m github.com/anchore/syft@latest` | 2026-09-14 |
| grype | v0.118.0 | `go list -m github.com/anchore/grype@latest` | 2026-09-14 |
| kind | v0.33.0 | `go list -m sigs.k8s.io/kind@latest` | 2026-09-14 |
| kubectl / Kubernetes | v1.37.0 | `go list -m k8s.io/kubernetes@latest` (kubectl's own module tags as `v0.37.0`, tracking the same minor) | 2026-09-14 |
| Go (toolchain, and the pin used for `apps/demo-api`'s `go.mod` and its Docker builder stage) | 1.27.1 | `go list -m -versions golang.org/toolchain` (highest `go1.X.Y` listed; go1.26.8 is the prior minor's latest patch) — corrects Phase 0's `mise.toml`, which had wrongly used this sandbox's preinstalled 1.24.7 instead of resolving it the same way as everything else | 2026-09-14 (corrected in Phase 1) |
| Helm | v3.22.0 | `go list -m helm.sh/helm/v3@latest` | 2026-09-14 |
| Kustomize | v5.8.1 | `go list -m sigs.k8s.io/kustomize/kustomize/v5@latest` | 2026-09-14 |
| Terraform (CLI) | v1.16.2 | `go list -m github.com/hashicorp/terraform@latest` | 2026-09-14 |
| tflint | v0.64.0 | `go list -m github.com/terraform-linters/tflint@latest` | 2026-09-14 |
| conftest | v0.70.0 | `go list -m github.com/open-policy-agent/conftest@latest` | 2026-09-14 |
| gitleaks | v8.30.1 | `go list -m github.com/gitleaks/gitleaks/v8@latest` | 2026-09-14 |
| yq | v4.53.6 | `go list -m github.com/mikefarah/yq/v4@latest` | 2026-09-14 |

## Python-distributed tooling

| Tool | Version | Resolved via | Date |
|---|---|---|---|
| pre-commit | v4.6.2 | `pypi.org/pypi/pre-commit/json` | 2026-09-14 |
| checkov | v3.3.17 | `pypi.org/pypi/checkov/json` | 2026-09-14 |
| mkdocs-material | v9.7.7 | `pypi.org/pypi/mkdocs-material/json` | 2026-09-14 |
| yamllint | v1.38.0 | `pypi.org/pypi/yamllint/json` | 2026-09-14 |

## Container base images (`apps/demo-api/Dockerfile`)

| Stage | Image:tag | Digest | Resolved via | Date |
|---|---|---|---|---|
| builder | `golang:1.27.1-alpine` | `sha256:cf6fca6641884b8433441b2b0652976f975e1d0fdd26d177eaaf8596087f3125` | Docker Registry v2 API against `registry-1.docker.io` (see method above) | 2026-09-14 |
| runtime | `gcr.io/distroless/static-debian12:nonroot` | `sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab` | Docker Registry v2 API against `gcr.io` | 2026-09-14 |

The runtime stage uses the explicit `-debian12` tag (distroless's current
recommended form) rather than the legacy bare `distroless/static` alias,
which also resolves but leaves the OS version implicit.

## Terraform providers (`infra/terraform/`)

| Provider | Version | Resolved via | Date |
|---|---|---|---|
| `hashicorp/aws` | 6.64.0 | `releases.hashicorp.com/terraform-provider-aws/` directory listing (its highest published `terraform-provider-aws_X.Y.Z_linux_amd64.zip`), SHA256-verified against that same host's `..._SHA256SUMS` file. This corrects the item deferred in Phase 0/1 below — the Go-module-proxy trick used for other tools resolves this specific provider to a stale, unrelated `v1.x` tag series, since its Go module path doesn't track its real (Terraform Registry) release versioning | 2026-09-14 (Phase 2) |

See `docs/fidelity.md` for how `terraform init`/`plan`/`test` actually ran
against this provider in a sandbox where `registry.terraform.io` itself is
blocked.

## Deferred — resolved when the phase that consumes them starts

Go-module resolution is only trustworthy when the module's import path
itself carries the major-version suffix (proof the maintainer publishes
through Go's module system). The entries below don't meet that bar here, or
need a source this sandbox cannot reach at all; guessing them now would
violate Operating Rule 4, so each is deferred to the phase that first needs
it and re-checked against a reachable source there. Two items are handled
differently — never pinned at all, on purpose, rather than deferred to a
later resolution: `modules/eks`'s `kubernetes_version` variable has no
default (AWS's supported-version list changes over time, so any value
hardcoded today would eventually be a guess), and `aws_eks_addon.pod_identity`
sets no `addon_version` (AWS picks its default rather than this repo pinning
one it can't check against a compatibility matrix). See `docs/fidelity.md`
for why those specific lookups aren't reachable from this sandbox.

| Item | Why deferred | Resolve in |
|---|---|---|
| `sigstore/scaffolding` chart/manifest version | GitHub-hosted, not a Go module release scheme this proxy can resolve | Phase 5/6 (local Fulcio/Rekor for the kind demo) |
| SLSA Build L3 generator reusable-workflow tag | Consumed by ref (`@vX.Y.Z`), GitHub-hosted | Phase 4 (build-sign-attest.yml) |
| Every third-party GitHub Action commit SHA (`actions/checkout`, `docker/build-push-action`, `sigstore/cosign-installer`, `aws-actions/configure-aws-credentials`, `anchore/sbom-action`, `github/codeql-action`, `ossf/scorecard-action`, `googleapis/release-please-action`, etc.) | `github.com`/`api.github.com` access from this sandbox is scoped to this session's own repo; each action's repo would need to be attached individually right before its workflow is authored | Whichever workflow first references it (Phases 3-9) |

## CLI availability in this sandbox (informational, not a version claim)

Installed and runnable (via `go install` against the pinned version above,
or a direct binary download for the two tools whose `go.mod` has `replace`
directives that block `go install`): `terraform`, `kubectl`, `helm`,
`kustomize`, `kind`, `cosign`, `syft`, `grype`, `gitleaks`, `tflint`,
`conftest`, `yq`, `chainsaw`, `pre-commit`, `yamllint`.

Not available here:
- **`kyverno` CLI** (`kubectl-kyverno`) — `kyverno/kyverno`'s `go.mod` carries
  `replace` directives, which Go refuses to honor for a remote `go install`
  ("must not contain directives that would cause it to be interpreted
  differently than if it were the main module"). The same class of error
  blocked a direct `go install` of `terraform` (worked around above via
  `releases.hashicorp.com`); no equivalent public binary CDN is reachable
  for kyverno-cli from this sandbox. Needed for real starting Phase 3 — will
  attach the `kyverno/kyverno` repo via `add_repo` at that point and build
  from a local clone, or find another route, rather than skip the check.
- **`checkov`** — `pip install` failed on an unrelated system package
  conflict (`packaging` installed by `apt` has no pip `RECORD`, so pip can't
  upgrade it). Needed starting Phase 2; will resolve then (likely a venv).
- **`mkdocs-material`** — not installed yet; not needed before Phase 8.
- **Docker daemon** — not reachable at all (`docker info` fails), so `kind`
  cannot actually bring up a cluster here regardless of the binary being
  installed. Every gate under Phases 5-7 that needs a running cluster will
  be written and validated for correctness (manifests, policy YAML, script
  logic) but the actual `make demo`/`make demo-attack` run has to happen in
  CI (`e2e-kind.yml`, a GitHub-hosted runner with Docker) or on a
  contributor's machine — never claimed as "passed" from inside this sandbox.
- **No AWS account** — `terraform plan`/`apply` against real AWS resources,
  and anything that needs live EKS/ECR, cannot be exercised here either.
