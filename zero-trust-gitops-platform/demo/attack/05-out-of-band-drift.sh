#!/usr/bin/env bash
# Attack 5/6: edit a live Deployment directly with kubectl, out of band from
# Git entirely. Argo CD's `selfHeal: true` (every ApplicationSet-generated
# demo-api Application, and every gitops/platform/* Application) is
# supposed to notice and revert it — proving the cluster's actual state is
# never allowed to permanently diverge from what's committed, no matter who
# has kubectl access.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

app_name="demo-api-dev"
before_replicas="$(kubectl -n "$NAMESPACE" get deployment/demo-api -o jsonpath='{.spec.replicas}')"
tampered_replicas=$((before_replicas + 7))

echo "EXPECTED: DENIED (out-of-band drift reverted by Argo CD self-heal)"
echo "==> tampering with demo-api out of band: replicas ${before_replicas} -> ${tampered_replicas}"
kubectl -n "$NAMESPACE" patch deployment/demo-api --type=merge -p "{\"spec\":{\"replicas\":${tampered_replicas}}}"

echo "==> waiting for Argo CD self-heal to revert it (gitops/platform/argocd/values.yaml sets"
echo "    a 60s reconciliation timeout for exactly this demo)"
deadline=$((SECONDS + 180))
reverted=0
while [ "$SECONDS" -lt "$deadline" ]; do
  current="$(kubectl -n "$NAMESPACE" get deployment/demo-api -o jsonpath='{.spec.replicas}')"
  if [ "$current" = "$before_replicas" ]; then
    reverted=1
    break
  fi
  sleep 5
done

echo "==> Argo CD's own audit trail for this Application:"
kubectl -n argocd get application "$app_name" \
  -o jsonpath='{.status.operationState.phase}{" — "}{.status.operationState.message}{"\n"}' || true
kubectl -n argocd get application "$app_name" \
  -o jsonpath='{range .status.history[-3:]}{.deployStartedAt}{" revision="}{.revision}{"\n"}{end}' || true

if [ "$reverted" -eq 1 ]; then
  echo "ACTUAL:   DENIED — replicas back to ${before_replicas}, drift reverted"
  exit 0
fi
echo "ACTUAL:   NOT DENIED — replicas still ${tampered_replicas} after 180s, drift was not reverted"
exit 1
