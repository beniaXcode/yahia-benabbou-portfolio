# Supply chain

What this repository actually produces, attaches to an image, and re-checks — end to end from
build to running pod.

## Build

`apps/demo-api/Dockerfile` builds from `golang:1.27.1-alpine`, pinned by digest (never a mutable
tag), with `CGO_ENABLED=0` and `-trimpath` for a reproducible binary (verified in Phase 1: two
builds of the same commit produce byte-identical output). The runtime stage is
`gcr.io/distroless/static-debian12:nonroot`, also pinned by digest — no shell, no package manager,
runs as UID 65532. Every digest in the Dockerfile is recorded, with its resolution method, in
[`versions.md`](versions.md).

## SBOM

`.github/workflows/build-sign-attest.yml` runs syft against the built image, producing both an
SPDX and a CycloneDX SBOM. Both are uploaded as workflow artifacts; the CycloneDX one is also
attached to the image as a cosign attestation (see below), which is what
[`policies/supply-chain/verify-sbom-attestation.yaml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/policies/supply-chain/verify-sbom-attestation.yaml)
checks at admission.

## Vulnerability gate

grype scans the built image against the SBOM. The workflow fails the build on any `CRITICAL`
finding, or any `HIGH` finding with an available fix (`--only-fixed --fail-on high` layered with
`--fail-on critical`) — a finding with no fix yet available doesn't block a build nothing could
have prevented, but a fixable one does.

## Signing — keyless

```
cosign sign --yes <image>@<digest>
```

reads the workflow's OIDC token, exchanges it with Fulcio for a certificate whose `subject` is the
exact workflow file + ref (`https://github.com/beniaXcode/yahia-benabbou-portfolio/.github/workflows/build-sign-attest.yml@refs/heads/main`)
and whose `issuer` is `https://token.actions.githubusercontent.com`, signs with a key generated for
this one operation, and publishes the signature plus a Rekor transparency-log entry. See
[ADR-0003](adr/0003-sigstore-keyless-signing.md) for why keyless was chosen over a static key pair,
and [`identity-model.md`](identity-model.md) for the OIDC exchange itself.

## Attestation

Two `cosign attest` calls follow the same keyless identity: one for the CycloneDX SBOM, one for a
SLSA Build L3 provenance statement produced by
[`slsa-framework/slsa-github-generator`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/.github/workflows/slsa-provenance.yml) (a reusable
workflow this repo calls with the built image and digest — see that workflow for exactly what it
records: builder ID, source repo, invocation parameters).

## Self-check

Before the workflow reports success, it runs the *exact* `cosign verify` and `cosign
verify-attestation` commands the README publishes for anyone to run independently — if the
signature this job just produced doesn't verify against the identity it's supposed to have, the
build fails here rather than shipping something a reviewer's own copy-pasted command would later
fail to confirm.

## Promotion

A separate workflow ([`promote.yml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/.github/workflows/promote.yml)) opens a pull request
that runs `kustomize edit set image demo-api=<repo>@<digest>` against one environment overlay —
the only change in that PR is the digest. Merging it is the only way an environment's deployed
image changes; there is no other path that writes to `gitops/apps/demo-api/overlays/*`.

## Admission-time re-verification

Kyverno re-checks all of the above independently, using the same identity the workflow's own
self-check used —
[`policies/supply-chain/verify-image-signature.yaml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/policies/supply-chain/verify-image-signature.yaml),
`verify-slsa-provenance.yaml`, `verify-sbom-attestation.yaml`. This is the difference between
"CI said it was fine" and "the cluster independently confirmed it" — a compromised or bypassed CI
run still cannot get an unsigned or wrongly-signed image admitted, because admission doesn't trust
CI's verdict, it re-derives its own (see `architecture.md`'s "no implicit trust in the artifact").

## Continuous re-verification

`gitops/platform/verification/cronjob.yaml` runs on a schedule, listing every currently-running
container's actual resolved digest and re-running `cosign verify` against each — catching a
signature or attestation that becomes invalid *after* deployment (a revoked Rekor entry, a registry
serving a substituted digest under the same tag before a restart), not just at the moment of
deploy. Results land in a ConfigMap Policy Reporter and a human can both read.

## Digest pinning, everywhere

No manifest this repository deploys ever references an image by mutable tag —
[`policies/supply-chain/require-image-digest.yaml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/policies/supply-chain/require-image-digest.yaml)
enforces it at admission, and `demo/attack/02-latest-tag.sh` proves the enforcement is real, not
just a convention.
