# Runbook: suspected compromise of the build/signing identity

**When to use this:** you believe `build-sign-attest.yml`'s OIDC identity, or the AWS role it
assumes, may have been used by an attacker (a malicious third-party Action in that workflow, a
leaked runner, a suspicious Rekor entry naming this project's identity for an image nobody here
built).

## 1. Contain first, investigate second

1. **Disable the workflow immediately**, not the runner: `gh workflow disable build-sign-attest.yml`
   (or delete/rename the workflow file in a hotfix PR merged with admin override if `gh` access
   isn't available) — this stops any further signing under this identity without needing to touch
   AWS or Sigstore, which have no "pause" button for a single workflow's trust.
2. **Do not rotate a signing key** — there isn't one to rotate (C3, ADR-0003). The identity being
   suspect is the *workflow itself*, so containment means stopping the workflow, not rotating a
   secret.
3. Check whether the suspicious activity had time to reach a real AWS session: the role's trust
   policy only ever grants a 15-minute session per run (`infra/terraform/modules/github-oidc-provider`)
   — CloudTrail's `AssumeRoleWithWebIdentity` events for that role, cross-referenced against
   `build-sign-attest.yml`'s own run history in GitHub, bound the exact blast-radius window.

## 2. Verify what was actually signed

```
cosign verify <suspect image>@<digest> \
  --certificate-identity-regexp '^https://github.com/beniaXcode/yahia-benabbou-portfolio/.github/workflows/build-sign-attest.yml@refs/heads/main$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

If this succeeds for an image nobody here recognizes building, the compromise is real and inside
the workflow itself (a malicious step, a compromised third-party Action) — not a forged signature,
since Fulcio's certificate binding to this exact workflow+ref is what `cosign verify` just
confirmed. Search Rekor (`https://search.sigstore.dev`) for every entry naming this identity in the
suspected time window; each one is a real signing event that happened, whether or not it was
intended.

## 3. Revoke trust, not just disable

Rotating the AWS side means changing the OIDC trust policy's `sub` condition
(`infra/terraform/modules/github-oidc-provider`) to reference a *new* ref or environment the
attacker's access doesn't carry over to — e.g., requiring a signed tag rather than any push to
`main`, if the compromise came through a merged PR. This is a Terraform change, reviewed and
applied through the normal path, not a manual `aws iam update-assume-role-policy` — the whole point
of C6 is that this trust relationship lives in code, not in someone's memory of what they typed at
a shell.

## 4. What admission would have caught, and what it wouldn't

Kyverno's `verify-image-signature` policy only ever trusts signatures from this exact
`subject`/`issuer` — an attacker without access to this specific workflow's OIDC token cannot
produce an image Kyverno would admit, no matter what they compromise elsewhere. If the compromise
*is* inside the workflow itself (scenario 1 in `docs/threat-model.md`), admission does not save
you: a malicious step inside `build-sign-attest.yml` legitimately produces a validly-signed image,
because the signature only proves *which workflow* built it, not that the workflow's own logic
wasn't tampered with. That is why containment (step 1) matters more than any downstream control.
