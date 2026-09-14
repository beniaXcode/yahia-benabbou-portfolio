#!/usr/bin/env bash
# Attack 4/6 — BRIEF.md calls this "the most convincing one": deploy an
# image that genuinely *is* signed, correctly, with a real cosign
# signature that verifies — just not by the identity this cluster trusts.
# Proves policies/supply-chain/verify-image-signature.yaml checks *who*
# signed, not merely *that* something signed.
#
# In production (Fulcio keyless), "a different identity" means a signature
# whose certificate names a different GitHub Actions workflow/repo. This
# demo runs the documented local-signing fallback instead (a `keys`
# attestor pinned to one ephemeral public key — see
# gitops/platform/kyverno/local-key-attestor/ and docs/fidelity.md), so the
# equivalent here is signing with a second, different, never-registered key
# pair: the mechanism Kyverno checks (does the signature verify against
# *this specific* trusted identity/key) is identical either way.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=./lib.sh
source "$root/demo/attack/lib.sh"

deployed_image="$(kubectl -n "$NAMESPACE" get deployment/demo-api -o jsonpath='{.spec.template.spec.containers[0].image}')"

echo "==> generating a second, throwaway key pair — a stand-in for 'a different signer identity'"
attacker_key_dir="$(mktemp -d)"
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix "${attacker_key_dir}/attacker"

echo "==> re-signing the already-legitimately-built image with the attacker's key"
echo "    (the image content is genuine; only the signer is not who this cluster trusts)"
COSIGN_PASSWORD="" cosign sign --key "${attacker_key_dir}/attacker.key" --tlog-upload=false -y "$deployed_image"

manifest="$(mktemp)"
cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attack-wrong-signer
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
      image: ${deployed_image}
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests: {cpu: 10m, memory: 16Mi}
        limits: {cpu: 100m, memory: 64Mi}
EOF

trap 'cleanup_resource pod/attack-wrong-signer; rm -f "$manifest"; rm -rf "$attacker_key_dir"' EXIT
echo "note: the legitimate signature from demo/up.sh's own key is *also* still attached to"
echo "      this same digest — this attack adds a second, additional signature, it does not"
echo "      remove the real one. A verifier that accepted *any* valid signature from *any*"
echo "      key would wrongly pass here; Kyverno's attestor is pinned to one specific"
echo "      public key (cosign-local-demo-pubkey), so only that one counts."
expect_denied "image signed by an untrusted identity, verify-image-signature.yaml" -- kubectl apply -f "$manifest"
