# Why this policy's "pass" fixture isn't run through `kyverno test` here

`verify-slsa-provenance.yaml` uses a Kyverno `verifyImages` rule with a **keyless**
Sigstore attestor. Verifying a keyless signature/attestation requires
fetching Fulcio's current root-of-trust bundle from
`tuf-repo-cdn.sigstore.dev` and querying Rekor — both real network calls,
every time, with no offline/cached fallback in Kyverno itself.

This sandbox's network policy blocks `tuf-repo-cdn.sigstore.dev`
(`403 Forbidden`), confirmed directly:

```
failed to get roots from fulcio: failed to fetch Fulcio roots: initializing
tuf: updating local metadata and targets: error updating to TUF remote
mirror: tuf: failed to download 13.root.json: Get
"https://tuf-repo-cdn.sigstore.dev/13.root.json": Forbidden
```

That means **every** image reference — correctly signed or not — fails
identically here, for a reason that has nothing to do with this policy's
actual logic. `resource-fail.yaml` sidesteps that: an image with no digest
at all is rejected by Kyverno before it would ever attempt the Fulcio/Rekor
call, so that half of the pair is genuinely, deterministically verified
offline (see the test result above).

The pass case — a real signed image getting through — is proven for real
in `demo/attack/01-unsigned-image.sh` and
`demo/attack/04-wrong-signer-identity.sh` (Phase 7), which run against an
actual `kind` cluster with real Sigstore/Rekor access (or the local
scaffolding described in `docs/fidelity.md`), and in CI's
`e2e-kind.yml` (Phase 4+), which runs on a GitHub-hosted runner with
normal network access. That is the correct layer to verify a control that
fundamentally depends on live cryptographic infrastructure — not a second,
fake offline test that would just assert the sandbox's network policy
rather than this policy's logic.
