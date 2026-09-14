# Runbook: Argo CD drift or sync failure

**When to use this:** an Application shows `OutOfSync`, `Degraded`, or its live state doesn't match
what's committed, and self-heal doesn't appear to be resolving it.

## 1. Check the Application's own status

```
kubectl -n argocd get application <name> -o yaml
kubectl -n argocd get application <name> \
  -o jsonpath='{.status.sync.status}{" / "}{.status.health.status}{"\n"}'
```

`status.operationState` shows the last sync attempt's phase and message;
`status.resources[].status` shows which specific object is out of sync and how.

## 2. Distinguish "hasn't synced yet" from "can't sync"

- **Not yet reconciled:** `gitops/platform/argocd/values.yaml` sets `timeout.reconciliation: 60s`
  for this demo specifically (a real deployment would use the chart's own 180s default) — wait one
  full interval before treating this as stuck.
- **Sync error:** `status.operationState.message` names the actual failure — a webhook rejection
  (see the Kyverno admission runbook), a malformed manifest (`kustomize build` the overlay directly
  to reproduce), or a `ComparisonError` (the Application's own `source` no longer resolves — check
  the repo URL/path/revision in the Application manifest itself).

## 3. Out-of-band drift specifically

If `status.sync.status` is `OutOfSync` and the diff shown is something *nobody committed* (a
`kubectl edit`/`patch` against the live object), this is exactly what `selfHeal: true` exists to
revert — see `demo/attack/05-out-of-band-drift.sh` for the mechanism demonstrated end to end. If it
is *not* reverting:

1. Confirm `selfHeal: true` is actually set on that Application (`gitops/apps/demo-api/applicationset.yaml`
   or the specific `gitops/platform/*/application.yaml`) — a manually-created Application bypassing
   the committed template wouldn't have it.
2. Check `status.operationState` for a sync error *blocking* the heal (the drifted state might
   itself now fail admission in a way the correct, committed state didn't — unlikely, since the
   committed state is what's being restored, but worth ruling out).
3. If the drift is in a **platform namespace** (`argocd`, `kyverno`, `external-secrets`,
   `policy-reporter`) rather than an application namespace, treat this as a potential attempt to
   disable the platform's own controls — see `docs/threat-model.md` scenario 5's residual-risk
   note. Escalate rather than just re-syncing.

## 4. Force a resync if genuinely stuck

```
kubectl -n argocd patch application <name> --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}'
```

Only after confirming via steps 1–3 that this isn't masking a real underlying failure — a forced
sync that keeps failing the same way is a symptom to fix, not something to repeat.
