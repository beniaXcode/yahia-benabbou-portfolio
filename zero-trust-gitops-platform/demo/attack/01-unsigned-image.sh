#!/usr/bin/env bash
# Attack 1/6: deploy an image that was built and pushed like any other, but
# never signed at all. Everything else about it is legitimate — correct
# registry, correct digest reference — so this isolates exactly one
# control: policies/supply-chain/verify-image-signature.yaml.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

registry_port=5000
image_repo="beniaxcode/yahia-benabbou-portfolio/demo-api"
image_host="kind-registry.kind-registry.svc.cluster.local:${registry_port}"

echo "==> building a fresh, deliberately unsigned demo-api image"
local_ref="localhost:${registry_port}/${image_repo}:attack-unsigned"
make -C "$root" image IMAGE="$local_ref"
docker push "$local_ref"
digest="$(curl -fsS -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
  -I "http://localhost:${registry_port}/v2/${image_repo}/manifests/attack-unsigned" \
  | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}')"
image_ref="${image_host}/${image_repo}@${digest}"
echo "    built (never signed): $image_ref"

manifest="$(mktemp)"
cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attack-unsigned-image
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
      image: ${image_ref}
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests: {cpu: 10m, memory: 16Mi}
        limits: {cpu: 100m, memory: 64Mi}
EOF

trap 'cleanup_resource pod/attack-unsigned-image; rm -f "$manifest"' EXIT
expect_denied "unsigned image, verify-image-signature.yaml" -- kubectl apply -f "$manifest"
