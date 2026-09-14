#!/usr/bin/env bash
# Brings up the full offline GitOps loop this repo demonstrates (BRIEF §6,
# Phase 5/6's gate; C10: no AWS account, ≤15 minutes). Never run for real in
# this sandbox — no Docker daemon is reachable here (see docs/fidelity.md) —
# but every step below is a real, complete command a contributor with
# Docker can actually run.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name=zero-trust-gitops-platform
registry_name=kind-registry
registry_port=5000

# Calico v3.32.2 — see docs/versions.md. Pinned by tag, not "latest":
# reapplying the exact same manifests on every `make demo` run is what
# keeps this reproducible.
calico_operator_url="https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/tigera-operator.yaml"
calico_resources_url="https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/custom-resources.yaml"

echo "==> checking for a reachable Docker daemon"
if ! docker info >/dev/null 2>&1; then
  echo "no reachable Docker daemon — this is exactly the gap docs/fidelity.md records for this sandbox" >&2
  exit 1
fi

echo "==> starting the local pull-through registry (avoids real registries' anonymous-pull rate limits)"
if [ "$(docker inspect -f '{{.State.Running}}' "$registry_name" 2>/dev/null || true)" != "true" ]; then
  docker run -d --restart=always -p "127.0.0.1:${registry_port}:5000" --name "$registry_name" registry:2
fi

echo "==> creating the kind cluster (default CNI disabled — see kind-cluster.yaml)"
if ! kind get clusters 2>/dev/null | grep -qx "$cluster_name"; then
  kind create cluster --config "$root/demo/kind-cluster.yaml"
fi
docker network connect kind "$registry_name" 2>/dev/null || true

echo "==> installing Calico (kind's default CNI does not enforce NetworkPolicy at all — C9 needs one that does)"
kubectl apply -f "$calico_operator_url"
kubectl apply -f "$calico_resources_url"
kubectl -n calico-system rollout status deployment/calico-kube-controllers --timeout=180s
kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=180s

echo "==> making the local registry reachable by real cluster-DNS name too, not just"
echo "    from the kind nodes: Kyverno's verifyImages step runs *inside a pod* and"
echo "    resolves images via CoreDNS like any other in-cluster client, which"
echo "    kind-cluster.yaml's node-level containerd mirror does nothing for. A"
echo "    Service + hand-written Endpoints pointing at the container's real address"
echo "    is the standard way to give an external, non-Kubernetes backend a normal"
echo "    in-cluster DNS name (no selector: nothing should ever try to manage these"
echo "    Endpoints automatically)."
kubectl create namespace kind-registry --dry-run=client -o yaml | kubectl apply -f -
registry_ip="$(docker inspect -f '{{ (index .NetworkSettings.Networks "kind").IPAddress }}' "$registry_name")"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kind-registry
  namespace: kind-registry
spec:
  ports:
    - port: ${registry_port}
---
apiVersion: v1
kind: Endpoints
metadata:
  name: kind-registry
  namespace: kind-registry
subsets:
  - addresses:
      - ip: ${registry_ip}
    ports:
      - port: ${registry_port}
EOF

echo "==> building demo-api and pushing it to the local registry"
image_repo="beniaxcode/yahia-benabbou-portfolio/demo-api"
image_host="kind-registry.kind-registry.svc.cluster.local:${registry_port}"
local_ref="localhost:${registry_port}/${image_repo}:local"
make -C "$root" image IMAGE="$local_ref"
docker push "$local_ref"
digest="$(docker buildx imagetools inspect "$local_ref" --format '{{json .Manifest}}' 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["digest"])' 2>/dev/null || true)"
if [ -z "$digest" ]; then
  # Fallback for a plain (non-buildx) docker: read it straight from the
  # registry's own v2 API, the same method docs/versions.md documents for
  # every other digest resolved in this repo.
  digest="$(curl -fsS -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
    -I "http://localhost:${registry_port}/v2/${image_repo}/manifests/local" \
    | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}')"
fi
# Same content, two addresses: cosign (running here, on the host) reaches
# the registry via its published port; the digest itself is content-derived
# and identical no matter which hostname was used to push it, so it is
# exactly as valid against $image_host, which is what the cluster uses.
image_ref="${image_host}/${image_repo}@${digest}"
echo "    built and pushed: $image_ref"

echo "==> generating an ephemeral cosign key pair (never committed, discarded with the cluster) and signing that image"
key_dir="$(mktemp -d)"
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix "${key_dir}/cosign"
COSIGN_PASSWORD="" cosign sign --key "${key_dir}/cosign.key" --tlog-upload=false -y "$image_ref"

echo "==> pointing every overlay at the freshly signed digest"
for env in dev staging prod; do
  (cd "$root/gitops/apps/demo-api/overlays/$env" && kustomize edit set image "demo-api=${image_ref}")
done

echo "==> publishing the ephemeral public key where the local-key-attestor overlay expects it"
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kyverno create secret generic cosign-local-demo-pubkey \
  --from-file=cosign.pub="${key_dir}/cosign.pub" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -rf "$key_dir"

echo "==> seeding the ExternalSecret 'local-demo' backend substitute (see gitops/platform/external-secrets/manifests/cluster-secret-store.yaml)"
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl -n external-secrets create secret generic demo-api-demo-secret \
  --from-literal=DEMO_SECRET="local-demo-value-$(date -u +%s)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> one-time bootstrap install of Argo CD (the classic chicken-and-egg: the"
echo "    Application CRD gitops/bootstrap/*.yaml needs doesn't exist until Argo CD"
echo "    itself has been installed once, imperatively — after this, root-platform's"
echo "    own Application takes over reconciling this same Argo CD's Helm-chart"
echo "    lifecycle going forward, self-managing exactly as its own comment says)"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml"
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> applying the two app-of-apps roots — everything else in gitops/ from here on is pure GitOps"
kubectl apply -f "$root/gitops/bootstrap/root-platform.yaml"
kubectl apply -f "$root/gitops/bootstrap/root-apps.yaml"

echo "==> waiting for every Application to reach Synced + Healthy (Phase 5 gate)"
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced --timeout=600s \
  application.argoproj.io --all
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s \
  application.argoproj.io --all

echo "==> done — Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8081:443"
