#!/usr/bin/env bash
# Attack 3/6: a privileged, host-mounting, root pod — the direct
# container-escape combination policies/workload-hardening/
# disallow-host-namespaces.yaml exists specifically to catch (it also
# covers hostNetwork/hostIPC/hostPID, exercised here via hostPID for good
# measure). Uses a real, already-signed image (this repo's own base
# demo-api) — this attack is entirely about the pod *spec*, not the image.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

deployed_image="$(kubectl -n "$NAMESPACE" get deployment/demo-api -o jsonpath='{.spec.template.spec.containers[0].image}')"

manifest="$(mktemp)"
cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attack-privileged-pod
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: demo-api
    app.kubernetes.io/managed-by: attack-script
spec:
  hostPID: true
  containers:
    - name: demo-api
      image: ${deployed_image}
      securityContext:
        privileged: true
        runAsUser: 0
      volumeMounts:
        - name: host-root
          mountPath: /host
      resources:
        requests: {cpu: 10m, memory: 16Mi}
        limits: {cpu: 100m, memory: 64Mi}
  volumes:
    - name: host-root
      hostPath:
        path: /
EOF

trap 'cleanup_resource pod/attack-privileged-pod; rm -f "$manifest"' EXIT
expect_denied "privileged + hostPath + hostPID pod, disallow-host-namespaces.yaml" -- kubectl apply -f "$manifest"
