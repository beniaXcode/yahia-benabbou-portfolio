#!/usr/bin/env bash
# Attack 2/6: deploy demo-api:latest — a mutable tag, not a digest. Even if
# it happened to be signed, a tag can be repointed at any image after the
# fact, so policies/supply-chain/require-image-digest.yaml denies it
# unconditionally, before signature verification is ever reached (C5).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

registry_port=5000
image_repo="beniaxcode/yahia-benabbou-portfolio/demo-api"
image_host="kind-registry.kind-registry.svc.cluster.local:${registry_port}"

echo "==> pushing demo-api under the mutable tag ':latest' (reusing whatever was last built here)"
local_ref="localhost:${registry_port}/${image_repo}:latest"
make -C "$root" image IMAGE="$local_ref"
docker push "$local_ref"

manifest="$(mktemp)"
cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attack-latest-tag
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
    - name: demo-api
      image: ${image_host}/${image_repo}:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests: {cpu: 10m, memory: 16Mi}
        limits: {cpu: 100m, memory: 64Mi}
EOF

trap 'cleanup_resource pod/attack-latest-tag; rm -f "$manifest"' EXIT
expect_denied "mutable :latest tag, require-image-digest.yaml" -- kubectl apply -f "$manifest"
