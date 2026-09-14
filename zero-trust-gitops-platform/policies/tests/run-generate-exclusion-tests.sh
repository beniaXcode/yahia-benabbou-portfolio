#!/usr/bin/env bash
# `kyverno test`'s declarative results schema has no clean way to assert
# "this generate rule must NOT fire" (its resources/generatedResource
# fields are keyed to a resource a generate rule actually produced, so
# there's nothing to point at for an excluded namespace) — the "pass"
# half of each generate policy's fixture pair is tested declaratively in
# kyverno-test.yaml; this script covers the other half: that kube-system
# is excluded and produces no generated resource, using `kyverno apply`
# directly instead. Used by `make policy-test`.
set -euo pipefail

policies_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/excluded-namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
EOF

fail=0

for policy in default-deny-networkpolicy namespace-resourcequota; do
  out="$(kyverno apply "$policies_dir/generate/$policy.yaml" --resource "$tmpdir/excluded-namespace.yaml" 2>&1)"
  if echo "$out" | grep -q "^policy $policy applied to"; then
    echo "MISMATCH: $policy generated a resource for the excluded kube-system namespace, but it should have been skipped"
    echo "$out"
    fail=1
  else
    echo "OK: $policy correctly did not generate anything for the excluded kube-system namespace"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "generate-exclusion tests: FAILED"
  exit 1
fi

echo "generate-exclusion tests: OK"
