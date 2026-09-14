# 0003. Sigstore keyless signing over a static key pair

Status: Accepted

## Context

C3 requires that no private signing key ever exists for an attacker to steal, and C4 requires that
admission verify *who* built an image, not merely that *something* signed it. A traditional cosign
workflow generates a long-lived key pair once, stores the private half as a CI secret, and signs
with it forever — meaning the signing identity is "whoever has that secret," and a leaked secret
lets an attacker sign anything, indefinitely, as this project.

## Decision

Production signing is keyless: `build-sign-attest.yml` exchanges its GitHub Actions OIDC token
(the same one used for AWS STS) with Fulcio for a certificate binding the signature to the exact
workflow file, ref, and repository, and generates a fresh signing key for that one operation only
— nothing persists afterward. Every signature and attestation is logged to Rekor, a public
transparency log, so a signature's existence is independently auditable outside this repository's
own control.

## Consequences

There is no signing secret to rotate, leak, or restrict access to — the identity *is* the workflow
identity, verifiable by anyone who trusts Fulcio's public root of trust, and revoking the ability
to sign as this project means changing the workflow's permissions or repository access, not
rotating a key. The cost: signing now depends on Sigstore's public-good infrastructure being
reachable and trustworthy (see `docs/threat-model.md`'s "what would actually break this" — a
Sigstore compromise is explicitly out of scope for this repository to defend against) and on this
sandbox's own network policy, which blocks `tuf-repo-cdn.sigstore.dev` — meaning the real keyless
flow has never been exercised end-to-end from this build environment; only a GitHub-hosted runner
with real internet access proves it (`docs/fidelity.md`, Phase 3). The local `kind` demo,
which also cannot reach Fulcio, uses a documented fallback instead — see
[ADR-0006](0006-local-demo-fidelity-fallbacks.md).
