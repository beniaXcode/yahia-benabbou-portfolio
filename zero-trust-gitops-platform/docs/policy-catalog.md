# Policy catalog

**Generated from the annotations on every file in `policies/` by
`tools/gen-policy-catalog.sh` — do not hand-edit.** Run `make
policy-catalog` after adding or changing a policy; CI fails the build
if this file doesn't match what that command produces.

## Supply Chain

### Allowed Registries

- **Policy file:** [`policies/supply-chain/allowed-registries.yaml`](../policies/supply-chain/allowed-registries.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** NIST SSDF PO.5.1, CIS EKS 5.4.1, SOC 2 CC6.1
- **Tests:** [`policies/tests/allowed-registries`](../policies/tests/allowed-registries)

Every container and initContainer image must come from this project's own registry — either its ECR repository (the Terraform- provisioned production target, see infra/terraform/modules/ecr) or its GHCR namespace (what this specific deployment's CI actually pushes to, since no AWS account backs it — see docs/fidelity.md) — with two narrow, explicitly digest-pinned exceptions for the upstream tooling images gitops/apps/demo-api/base's PreSync verification hook and Phase 6's continuous-verification CronJob run (cosign, and a kubectl-capable image the CronJob pairs it with — see that CronJob's own comments for why two images are needed): neither runs this project's own application code, and each is pinned to one exact digest, rotated only by editing this policy alongside docs/versions.md. No Docker Hub image otherwise, no arbitrary third-party registry.

**Why this exists:** Signature verification only means something if the signer's identity also implies where the image lives. Allowing arbitrary registries would let an attacker who compromises any credential with cluster write access deploy an image from a registry this platform never pushes to or scans, sidestepping the ECR-side push/pull IAM scoping in infra/terraform/modules/ecr (or GHCR's equivalent package permissions) entirely.

### Require Image Digest

- **Policy file:** [`policies/supply-chain/require-image-digest.yaml`](../policies/supply-chain/require-image-digest.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** SLSA v1.0 Build L3 (immutable references), NIST SSDF PS.3.1, CIS EKS 5.4.1
- **Tests:** [`policies/tests/require-image-digest`](../policies/tests/require-image-digest)

Every container and initContainer image reference must include a @sha256:... digest. A bare tag, including :latest, is rejected.

**Why this exists:** A tag can be repointed to different image content at any time after admission approved it — pushing new bytes to an old tag silently swaps what's running. A digest can't be repointed. Without this control, verify-image-signature.yaml's signature check could pass once against a tag and then be bypassed by retagging that same tag to unsigned content later (C5).

### Verify Image Signature (Keyless)

- **Policy file:** [`policies/supply-chain/verify-image-signature.yaml`](../policies/supply-chain/verify-image-signature.yaml)
- **Severity:** critical
- **Subject:** Pod
- **Compliance mapping:** SLSA v1.0 Build L3, NIST SSDF PS.2.1/PS.3.2, CIS EKS 5.4.1, SOC 2 CC6.1/CC8.1
- **Tests:** [`policies/tests/verify-image-signature`](../policies/tests/verify-image-signature)

Every image must carry a valid Sigstore keyless signature whose Fulcio certificate identity matches this project's own release workflow — not merely "a" signature from anyone.

**Why this exists:** This is the actual admission gate the whole platform is built around (C4): it re-verifies cryptographic build identity at deploy time rather than trusting that CI did its job once. An attacker who gets write access to the cluster (a stolen kubeconfig, a compromised CI job with cluster credentials) still cannot run an image unless it was built and signed by this exact GitHub Actions workflow — signing it themselves, even with a real Sigstore identity, fails because the certificate subject/issuer won't match.

### Verify SBOM Attestation

- **Policy file:** [`policies/supply-chain/verify-sbom-attestation.yaml`](../policies/supply-chain/verify-sbom-attestation.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** NIST SSDF PS.3.2/RV.1.1, SLSA v1.0 (Provenance-Available), PCI-DSS v4 6.3.2
- **Tests:** [`policies/tests/verify-sbom-attestation`](../policies/tests/verify-sbom-attestation)

Every image must carry a signed CycloneDX SBOM attestation from this project's own release workflow.

**Why this exists:** A signature and provenance prove *who* built the image; an SBOM records *what's inside it*. Without a verified SBOM attestation, a compromised or outdated base image or dependency (threat-model scenario 3) has no machine-readable record for grype's continuous re-verification job or an incident responder to check against — the SBOM has to exist and be tied to this exact image by signature, not generated after the fact from whatever is currently running.

### Verify SLSA Provenance Attestation

- **Policy file:** [`policies/supply-chain/verify-slsa-provenance.yaml`](../policies/supply-chain/verify-slsa-provenance.yaml)
- **Severity:** critical
- **Subject:** Pod
- **Compliance mapping:** SLSA v1.0 Build L3 (Provenance-Available/Authentic), NIST SSDF PS.3.2
- **Tests:** [`policies/tests/verify-slsa-provenance`](../policies/tests/verify-slsa-provenance)

Every image must carry a signed SLSA provenance attestation (predicateType slsa.dev/provenance/v1) from this project's own release workflow.

**Why this exists:** verify-image-signature.yaml proves the image was signed by the right identity; this proves *how* it was built — the source repo, the builder, the entry point — matches what the SLSA Build L3 generator recorded, not just that a signature is present. A malicious insider who merges a bad change (threat-model scenario 2) still produces an image whose provenance honestly names this repo and this workflow; it does not let a manually-built or hand-assembled image forge that provenance and pass.

## Workload Hardening

### Disallow Host Namespaces, hostPath, and Privileged Containers

- **Policy file:** [`policies/workload-hardening/disallow-host-namespaces.yaml`](../policies/workload-hardening/disallow-host-namespaces.yaml)
- **Severity:** critical
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.2.2/5.2.3/5.2.4, NIST SSDF PS.1.1, SOC 2 CC6.1
- **Tests:** [`policies/tests/disallow-host-namespaces`](../policies/tests/disallow-host-namespaces)

Pods must not use hostNetwork, hostIPC, or hostPID, must not mount a hostPath volume, and no container may run privileged.

**Why this exists:** Each of these is a direct escape from the container boundary to the node: hostNetwork/hostIPC/hostPID share the node's own namespaces, a hostPath volume reads/writes the node's filesystem directly, and a privileged container gets effectively all root capabilities plus device access. Any one of these makes every other hardening control in this directory close to meaningless for that workload.

### Disallow Privilege Escalation

- **Policy file:** [`policies/workload-hardening/disallow-privilege-escalation.yaml`](../policies/workload-hardening/disallow-privilege-escalation.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.2.10, NIST SSDF PS.1.1
- **Tests:** [`policies/tests/disallow-privilege-escalation`](../policies/tests/disallow-privilege-escalation)

Every container must set securityContext.allowPrivilegeEscalation: false.

**Why this exists:** This is the setting that stops a container process from gaining more privileges than its parent had (via a setuid binary, for example) even if every other hardening control here is in place. Leaving it unset defaults to allowing escalation on most runtimes.

### Drop All Capabilities

- **Policy file:** [`policies/workload-hardening/drop-all-capabilities.yaml`](../policies/workload-hardening/drop-all-capabilities.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.2.9, NIST SSDF PS.1.1
- **Tests:** [`policies/tests/drop-all-capabilities`](../policies/tests/drop-all-capabilities)

Every container must explicitly drop the ALL Linux capability set.

**Why this exists:** Containers default to a non-trivial set of Linux capabilities (NET_RAW, CHOWN, and others) that almost no ordinary web workload needs and that meaningfully widen what a compromised process can do on the node. Dropping ALL and adding back only what's actually needed (nothing, for demo-api) shrinks that surface to zero by default instead of trusting every workload author to remember to ask.

### Require Read-Only Root Filesystem

- **Policy file:** [`policies/workload-hardening/require-readonly-rootfs.yaml`](../policies/workload-hardening/require-readonly-rootfs.yaml)
- **Severity:** medium
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.2.5, NIST SSDF PS.1.1
- **Tests:** [`policies/tests/require-readonly-rootfs`](../policies/tests/require-readonly-rootfs)

Every container must set securityContext.readOnlyRootFilesystem: true.

**Why this exists:** A writable root filesystem is what lets a compromised process drop a second-stage payload, patch a binary, or persist across a restart in the first place. demo-api's distroless runtime image has no shell to write with anyway; this makes that true for any workload, not just ones built distroless.

### Require Resource Requests and Limits

- **Policy file:** [`policies/workload-hardening/require-resource-limits.yaml`](../policies/workload-hardening/require-resource-limits.yaml)
- **Severity:** medium
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.7.3, NIST SSDF PS.1.1
- **Tests:** [`policies/tests/require-resource-limits`](../policies/tests/require-resource-limits)

Every container must set cpu and memory requests and limits.

**Why this exists:** An unbounded container is a denial-of-service risk to every other workload on its node — one runaway or compromised process can starve everything sharing that node of CPU or memory. This is capacity hygiene as much as security, but the two overlap: a workload with no limits is also the workload most useful to an attacker running something resource-intensive (crypto-mining, a brute-force loop) without immediately standing out.

### Require runAsNonRoot

- **Policy file:** [`policies/workload-hardening/require-run-as-nonroot.yaml`](../policies/workload-hardening/require-run-as-nonroot.yaml)
- **Severity:** high
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.2.1, NIST SSDF PS.1.1, PCI-DSS v4 6.4.1
- **Tests:** [`policies/tests/require-run-as-nonroot`](../policies/tests/require-run-as-nonroot)

Pods must set spec.securityContext.runAsNonRoot: true.

**Why this exists:** A process root inside a container is one namespace escape or misconfigured volume mount away from being root on the node. This is redundant-by-design with demo-api's own Dockerfile USER 65532 — the point is that the cluster does not have to trust the image built that way; it re-asserts the same guarantee at admission for every workload, including ones this platform didn't build.

### Require seccompProfile RuntimeDefault

- **Policy file:** [`policies/workload-hardening/require-seccomp-runtimedefault.yaml`](../policies/workload-hardening/require-seccomp-runtimedefault.yaml)
- **Severity:** medium
- **Subject:** Pod
- **Compliance mapping:** CIS EKS 5.7.2, NIST SSDF PS.1.1
- **Tests:** [`policies/tests/require-seccomp-runtimedefault`](../policies/tests/require-seccomp-runtimedefault)

Pods must set spec.securityContext.seccompProfile.type: RuntimeDefault.

**Why this exists:** Without an explicit seccomp profile, most container runtimes still apply a sane default, but that default is implicit and can vary by runtime/version. RuntimeDefault filters the syscall surface a container can reach explicitly and consistently, which is exactly the kind of implicit-trust gap this platform's admission gate exists to close.

## Governance

### Disallow the Default Namespace

- **Policy file:** [`policies/governance/disallow-default-namespace.yaml`](../policies/governance/disallow-default-namespace.yaml)
- **Severity:** low
- **Subject:** Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob
- **Compliance mapping:** CIS EKS 5.7.4, NIST SSDF PO.3.1
- **Tests:** [`policies/tests/disallow-default-namespace`](../policies/tests/disallow-default-namespace)

Workloads must not be created in the default namespace.

**Why this exists:** The default namespace has no RBAC boundary, no NetworkPolicy of its own, and no ResourceQuota unless one is added by hand — everything generate/default-deny-networkpolicy.yaml and generate/namespace-resourcequota.yaml automatically provide for a real namespace is absent there because nothing ever "creates" the default namespace for those generate rules to react to. A workload landing there is a workload landing outside every other control in this policy set.

### Require Ownership Labels

- **Policy file:** [`policies/governance/require-ownership-labels.yaml`](../policies/governance/require-ownership-labels.yaml)
- **Severity:** low
- **Subject:** Pod
- **Compliance mapping:** SOC 2 CC7.2 (asset inventory), NIST SSDF PO.3.1
- **Tests:** [`policies/tests/require-ownership-labels`](../policies/tests/require-ownership-labels)

Pods must carry app.kubernetes.io/name and app.kubernetes.io/managed-by labels.

**Why this exists:** Policy Reporter's cluster-wide compliance report and the "who owns this" question during an incident (docs/runbooks/policy-violation-triage.md) are both useless if a workload can't be traced back to a name and a management path. This is the cheapest control in the whole library and the one most likely to matter at 2am.

### Require Liveness and Readiness Probes

- **Policy file:** [`policies/governance/require-probes.yaml`](../policies/governance/require-probes.yaml)
- **Severity:** low
- **Subject:** Pod
- **Compliance mapping:** SOC 2 CC7.2 (availability monitoring)
- **Tests:** [`policies/tests/require-probes`](../policies/tests/require-probes)

Every container must define both a readinessProbe and a livenessProbe.

**Why this exists:** Argo CD's Health status for an Application (gitops/platform's self-heal loop) depends on Kubernetes actually knowing whether a pod is healthy. A container with no probes reports Running the instant the process starts, whether or not demo-api's /healthz and /readyz endpoints are actually answering — the exact gap that turns a silent failure into an outage nobody notices.

## Governance

### Generate Default-Deny NetworkPolicy

- **Policy file:** [`policies/generate/default-deny-networkpolicy.yaml`](../policies/generate/default-deny-networkpolicy.yaml)
- **Severity:** high
- **Subject:** Namespace, NetworkPolicy
- **Compliance mapping:** CIS EKS 5.3.2, NIST SSDF PS.1.1, PCI-DSS v4 1.3
- **Tests:** [`policies/tests/default-deny-networkpolicy`](../policies/tests/default-deny-networkpolicy)

Every new namespace (excluding the built-in system namespaces) automatically gets a default-deny-all NetworkPolicy the moment it's created.

**Why this exists:** C9's "every namespace starts default-deny" is only actually true if it happens without a human remembering to add it — the whole point is that a namespace someone creates in a hurry doesn't sit wide open by default while they get around to writing NetworkPolicies for it. synchronize: true also means someone deleting this policy by hand gets it regenerated rather than the namespace quietly staying open.

### Generate Namespace ResourceQuota

- **Policy file:** [`policies/generate/namespace-resourcequota.yaml`](../policies/generate/namespace-resourcequota.yaml)
- **Severity:** medium
- **Subject:** Namespace, ResourceQuota
- **Compliance mapping:** CIS EKS 5.7.3, SOC 2 CC7.2 (availability)
- **Tests:** [`policies/tests/namespace-resourcequota`](../policies/tests/namespace-resourcequota)

Every new namespace (excluding the built-in system namespaces) automatically gets a baseline ResourceQuota the moment it's created.

**Why this exists:** require-resource-limits.yaml bounds what one container can consume; this bounds what one namespace can consume in total, so a namespace full of otherwise-compliant workloads still can't exhaust node capacity for every other tenant on the cluster. Same synchronize: true reasoning as the NetworkPolicy generate rule — this is meant to be structurally present, not remembered.
