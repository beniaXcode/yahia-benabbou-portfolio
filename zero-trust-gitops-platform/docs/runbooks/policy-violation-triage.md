# Runbook: policy violation triage

**When to use this:** Policy Reporter shows a `PolicyReport` with `fail` results, or a deploy was
rejected at admission and the on-call needs to know whether that's expected behavior or a real
incident.

## 1. Find the report

```
kubectl get policyreport -A
kubectl get policyreport -n <namespace> <name> -o yaml
```

Each result names the policy, the rule, the resource, and the exact message from that policy's
`validate.message` — the same text `policies/` defines, so it's directly greppable in this
repository (`docs/policy-catalog.md` lists every policy's message).

## 2. Classify

- **Admission-time rejection (a deploy never landed):** this is the system working — check
  `kubectl describe <kind> <name>` for the AdmissionReview response, or the submitter's own
  `kubectl apply` output, which shows the denial message directly. No further action needed unless
  the rejected resource was a *legitimate* deploy, in which case the manifest is wrong, not the
  policy — fix the input (CLAUDE.md's own hard rule: never weaken a policy to make something pass).
- **Background-scan finding on an already-running resource:** something was admitted before a
  policy existed, or a policy's own logic changed. Check `git log` on the relevant `policies/*.yaml`
  file for when the rule was added or tightened, and `git blame` the resource's own manifest for
  when it was last legitimately changed.

## 3. Cross-check against the shift-left gate

If the same resource's rendered manifest would also fail `ci.yml`'s shift-left check
(`kustomize build <overlay> | kyverno apply policies/*/`), the violation should already have been
caught before merge — its presence at admission or in the background scan means either the CI
check was bypassed (an out-of-band `kubectl apply` — see the drift runbook) or the manifest changed
after the shift-left check ran but before Argo CD synced it (a race, or a manual edit).

## 4. Escalate if

- The violating resource is in a platform namespace (`argocd`, `kyverno`, `external-secrets`,
  `policy-reporter`) rather than an application namespace — see the drift runbook's note on
  detecting an attempt to disable the platform's own controls.
- The same violation recurs across multiple, unrelated resources — likely a policy regression, not
  a one-off bad manifest. Re-run `kyverno test policies/` to confirm the policy library itself is
  still internally consistent before touching anything in the cluster.
