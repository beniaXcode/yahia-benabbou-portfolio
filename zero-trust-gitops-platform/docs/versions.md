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

## Deferred — resolved when the phase that consumes them starts

Go-module resolution is only trustworthy when the module's import path
itself carries the major-version suffix (proof the maintainer publishes
through Go's module system). The entries below don't meet that bar here, or
need a source this sandbox cannot reach at all; guessing them now would
violate Operating Rule 4, so each is deferred to the phase that first needs
it and re-checked against a reachable source there:

| Item | Why deferred | Resolve in |
|---|---|---|
| `hashicorp/aws` Terraform provider | Its Go module only exposes a stale `v1.x` tag series unrelated to its real (Terraform Registry) versioning; `registry.terraform.io` is not reachable from this sandbox | Phase 2 (Terraform modules) |
| `sigstore/scaffolding` chart/manifest version | GitHub-hosted, not a Go module release scheme this proxy can resolve | Phase 5/6 (local Fulcio/Rekor for the kind demo) |
| SLSA Build L3 generator reusable-workflow tag | Consumed by ref (`@vX.Y.Z`), GitHub-hosted | Phase 4 (build-sign-attest.yml) |
| Every third-party GitHub Action commit SHA (`actions/checkout`, `docker/build-push-action`, `sigstore/cosign-installer`, `aws-actions/configure-aws-credentials`, `anchore/sbom-action`, `github/codeql-action`, `ossf/scorecard-action`, `googleapis/release-please-action`, etc.) | `github.com`/`api.github.com` access from this sandbox is scoped to this session's own repo; each action's repo would need to be attached individually right before its workflow is authored | Whichever workflow first references it (Phases 3-9) |

## CLI availability in this sandbox (informational, not a version claim)

See the Phase 0 report for which of the above were actually installed and
runnable here versus written-correct-but-unverified (this sandbox has no
Docker daemon, so anything requiring `kind` cannot be exercised locally
regardless of whether the binary installs).
