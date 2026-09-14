#!/usr/bin/env bash
# Tears down everything demo/up.sh created. Idempotent — safe to run even if
# up.sh only got partway through.
set -euo pipefail

cluster_name=zero-trust-gitops-platform
registry_name=kind-registry

echo "==> deleting the kind cluster"
kind delete cluster --name "$cluster_name" 2>/dev/null || true

echo "==> stopping the local pull-through registry"
docker rm -f "$registry_name" >/dev/null 2>&1 || true

echo "==> done"
