#!/usr/bin/env bash
# Attack 6/6: from a pod with no EKS Pod Identity association at all, try
# to reach the cloud instance-metadata service and steal node/role
# credentials.
#
# Honest limitation (see docs/fidelity.md): a `kind` node is a Docker
# container, not an EC2 instance — there is no real IMDS endpoint here, and
# no launch-template hop-limit setting to test. This script proves the half
# that *is* real on kind: with no Pod Identity association and Calico
# actually enforcing gitops/apps/demo-api/base's default-deny-plus-explicit-
# allow NetworkPolicy (C9), a pod cannot open an arbitrary connection to
# 169.254.169.254 at all — traffic to it isn't in that NetworkPolicy's
# egress allowlist, so it is dropped before any credential-theft attempt
# could even begin. The other half — that IMDSv2 + hop limit 1 on a real
# EC2 node additionally defeats this even for a process that *can* reach
# 169.254.169.254 (a node-level, non-Pod-Identity workload) — is proven
# separately, in infra/terraform/modules/eks's launch template and its own
# Terraform tests (Phase 2), not by this kind demo.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

# demo-api's own image is distroless with no shell at all (a deliberate
# build constraint, not an oversight) — this probe needs something that can
# actually attempt a TCP connection, so it reuses the one other image
# already digest-pinned and allowlisted in policies/supply-chain/
# allowed-registries.yaml for exactly this reason (gitops/platform/
# verification's CronJob). Kyverno's verifyImages rules never even
# evaluate it: its imageReferences globs only match this project's own
# demo-api repository, so an image this far outside that scope is
# irrelevant to signature/provenance checks — only the registry allowlist
# and the digest-pin requirement apply to it, and it already satisfies both.
probe_image="docker.io/bitnami/kubectl@sha256:b29d8c1665b70817259ceecaea16ab27aab6368b48daf485d19436c809067492"

manifest="$(mktemp)"
cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attack-exfiltrate-node-role
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: demo-api
    app.kubernetes.io/managed-by: attack-script
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: ${probe_image}
      command: ["sleep", "300"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests: {cpu: 10m, memory: 32Mi}
        limits: {cpu: 100m, memory: 128Mi}
EOF

trap 'cleanup_resource pod/attack-exfiltrate-node-role; rm -f "$manifest"' EXIT

echo "==> deploying a pod with no Pod Identity association (this app has never had one — demo-api makes no AWS calls)"
kubectl apply -f "$manifest"
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/attack-exfiltrate-node-role --timeout=60s

echo "EXPECTED: DENIED (no NetworkPolicy egress rule permits reaching 169.254.169.254)"
# demo-api's own image is distroless/no-shell (C1's own build constraint),
# so the connection attempt has to come from something with a network tool
# — a plain TCP probe via /dev/tcp, run through `timeout` on the exec side,
# needs no extra binary in the target container at all.
if kubectl -n "$NAMESPACE" exec attack-exfiltrate-node-role -- \
    timeout 5 sh -c 'exec 3<>/dev/tcp/169.254.169.254/80' 2>&1; then
  echo "ACTUAL:   NOT DENIED — reached 169.254.169.254, credential theft would proceed from here"
  exit 1
fi
echo "ACTUAL:   DENIED — connection to 169.254.169.254 blocked or timed out"
