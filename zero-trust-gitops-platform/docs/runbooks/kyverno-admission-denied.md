# Runbook: a legitimate deploy was denied at admission

**When to use this:** a real, intended deploy (not an attack script) was rejected by Kyverno, and
someone needs to get it deployed without weakening a policy.

## 1. Read the exact denial

```
kubectl apply -f <manifest>
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
# ... resource <kind>/<name> was blocked due to the following policies ...
# <policy-name>:
#   <rule-name>: <the policy's own validate.message>
```

The message is the policy's own text — search `policies/*/*.yaml` for it to find the exact rule
and its `nearvic.io/rationale` annotation, which explains *why* the check exists, not just what it
checked.

## 2. Reproduce locally before touching anything

```
kustomize build <the overlay this manifest comes from> > /tmp/rendered.yaml
kyverno apply policies/*/ --resource /tmp/rendered.yaml
```

This is the exact command `ci.yml`'s shift-left step runs — if it fails here too, the fix belongs
in the manifest (in Git), not as a one-off cluster change, and a PR through the normal review path
is the right next step regardless of urgency (CLAUDE.md: never weaken a policy or skip a test to
make something pass).

## 3. Common causes and their real fixes

| Denial | Likely cause | Fix |
|---|---|---|
| `verify-image-signature` / `verify-slsa-provenance` / `verify-sbom-attestation` | The image was never signed/attested by `build-sign-attest.yml`, or was built from a fork/branch whose OIDC identity doesn't match the pinned `subject` | Rebuild from the exact workflow and ref this repo's policies trust — never widen the trusted identity to "fix" this |
| `require-image-digest` | The manifest references a tag, not a digest | Use the digest `promote.yml`'s PR set, or run `kustomize edit set image` yourself against the same digest |
| `allowed-registries` | The image is hosted somewhere this policy doesn't recognize | If it's a genuine new first-party registry (a real production ECR move), update the policy's `imageReferences`/allowlist deliberately, with a commit explaining why — never as a silent one-line admission fix |
| Workload-hardening (`require-run-as-nonroot`, `drop-all-capabilities`, etc.) | The pod spec genuinely needs elevated privileges | This is almost always a sign the workload doesn't belong in this cluster's default posture — escalate rather than add an exception |

## 4. If you believe the policy itself is wrong

Open a PR against the specific `policies/*.yaml` file with both the change and, if the fix changes
what the policy allows or denies, an updated `kyverno-test.yaml` pass/fail fixture pair
(`policies/tests/<policy-name>/`) proving the new behavior — `make kyverno-test` must stay green.
Never edit a policy directly on a live cluster; Argo CD's `selfHeal` would revert it on the next
reconciliation anyway, since the running policies are managed from `policies/` in Git (C8).
