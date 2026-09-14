---
name: verify-chain
description: Run the full verification a reviewer would run against a signed image digest
argument-hint: "[image-digest]"
allowed-tools: Bash(cosign *), Bash(curl *), Bash(jq *)
---

Given the image digest `$1` (e.g. `<registry>/<repo>@sha256:...`), run and show the output of
exactly what an external reviewer would run, in this order, and finish with a short human-readable
summary (signer identity, issuer, whether SBOM/SLSA attestations are present and valid, and the
Rekor log index):

1. `cosign verify` with `--certificate-identity-regexp` matching this project's release workflow
   and `--certificate-oidc-issuer https://token.actions.githubusercontent.com`.
2. `cosign verify-attestation --type cyclonedx` (or `spdx`) for the SBOM attestation.
3. `cosign verify-attestation --type slsaprovenance1` for the SLSA provenance attestation.
4. A Rekor lookup for the log entry backing that signature, printing the log index.

If any step fails, say plainly which one and why — do not soften a real verification failure into
a vague "mostly fine" summary.
