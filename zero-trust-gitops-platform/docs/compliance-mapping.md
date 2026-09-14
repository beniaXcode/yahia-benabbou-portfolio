# Compliance mapping

One row per control: what it is, the file that implements it, and which framework references it
maps to. The `nearvic.io/compliance` annotation on each Kyverno policy is the source of truth for
that policy's row — reproduced here verbatim, not re-derived, so this table can never drift from
what the policy itself claims. Frameworks referenced: **NIST SSDF (SP 800-218)**, **SLSA v1.0**,
**CIS EKS Benchmark**, **SOC 2 (CC6/CC7/CC8)**, **PCI-DSS v4 requirement 6**.

## Identity and credential management

| Control | Implementing file | Frameworks |
|---|---|---|
| No long-lived AWS credentials anywhere; short-lived OIDC-derived STS sessions only | `infra/terraform/modules/github-oidc-provider`, `.github/workflows/build-sign-attest.yml` | NIST SSDF PO.5.2/PS.1.1, SOC 2 CC6.1, PCI-DSS v4 8.3 |
| OIDC trust policy pins exact `sub` (repo+ref/environment) and `aud`, never a wildcard | `infra/terraform/modules/github-oidc-provider`, `infra/terraform/tests/github_oidc_provider.tftest.hcl`, `infra/terraform/policy/` (conftest, with a wildcard-`sub` fail fixture proving the guard has teeth) | NIST SSDF PS.1.1, CIS EKS 5.4.1, SOC 2 CC6.1 |
| EKS Pod Identity — scoped per-workload role, no node-role inheritance | `infra/terraform/modules/pod-identity`, `infra/terraform/modules/eks` | NIST SSDF PS.1.1, CIS EKS 5.4.1, SOC 2 CC6.1 |
| Zero GitHub Actions secrets besides the ambient `GITHUB_TOKEN` | `tools/check-no-secrets.sh`, `.github/workflows/verify-no-secrets.yml`, `.gitleaks.toml` | NIST SSDF PO.5.1, SOC 2 CC6.1 |
| Runtime secrets fetched at deploy time, never committed | `gitops/platform/external-secrets/manifests/cluster-secret-store.yaml`, `gitops/apps/demo-api/base/externalsecret.yaml` | NIST SSDF PS.1.1, SOC 2 CC6.1, PCI-DSS v4 3.5 |
| IMDSv2 required, hop limit 1 (defeats node-role credential theft) | `infra/terraform/modules/eks` (launch template) | CIS EKS 3.2.1, NIST SSDF PS.1.1 |

## Build and supply chain

| Control | Implementing file | Frameworks |
|---|---|---|
| Digest-pinned base images, reproducible build | `apps/demo-api/Dockerfile` | SLSA v1.0 (Provenance-Available), NIST SSDF PS.3.1 |
| SBOM generated for every build (SPDX + CycloneDX) | `.github/workflows/build-sign-attest.yml` (syft) | NIST SSDF PS.3.2, PCI-DSS v4 6.3.2 |
| Vulnerability gate blocks CRITICAL / fixable HIGH | `.github/workflows/build-sign-attest.yml` (grype) | NIST SSDF PW.4.4, PCI-DSS v4 6.3.3 |
| Keyless signing — no private signing key exists to leak | `.github/workflows/build-sign-attest.yml` (cosign sign), [ADR-0003](adr/0003-sigstore-keyless-signing.md) | SLSA v1.0 Build L3, NIST SSDF PS.2.1, SOC 2 CC8.1 |
| SLSA Build L3 provenance attestation | `.github/workflows/slsa-provenance.yml` | SLSA v1.0 Build L3 |
| Immutable tags + digest-only references | `infra/terraform/modules/ecr`, `policies/supply-chain/require-image-digest.yaml` | SLSA v1.0 (immutable references), NIST SSDF PS.3.1, CIS EKS 5.4.1 |
| `require-image-digest` — every manifest, digest not tag | `policies/supply-chain/require-image-digest.yaml` | SLSA v1.0 Build L3 (immutable references), NIST SSDF PS.3.1, CIS EKS 5.4.1 |
| `verify-image-signature` — admission checks *who* signed | `policies/supply-chain/verify-image-signature.yaml` | SLSA v1.0 Build L3, NIST SSDF PS.2.1/PS.3.2, CIS EKS 5.4.1, SOC 2 CC6.1/CC8.1 |
| `verify-slsa-provenance` — admission checks *how* it was built | `policies/supply-chain/verify-slsa-provenance.yaml` | SLSA v1.0 Build L3 (Provenance-Available/Authentic), NIST SSDF PS.3.2 |
| `verify-sbom-attestation` — admission checks the SBOM is attached and signed | `policies/supply-chain/verify-sbom-attestation.yaml` | NIST SSDF PS.3.2/RV.1.1, SLSA v1.0 (Provenance-Available), PCI-DSS v4 6.3.2 |
| `allowed-registries` — only this project's own registry | `policies/supply-chain/allowed-registries.yaml` | NIST SSDF PO.5.1, CIS EKS 5.4.1, SOC 2 CC6.1 |
| Continuous re-verification of running images | `gitops/platform/verification/cronjob.yaml` | NIST SSDF PO.3.3/RV.1.1, SOC 2 CC7.2 |
| Dependency and base-image update automation | `.github/dependabot.yml` | NIST SSDF PW.4.1, PCI-DSS v4 6.3.3 |

## Workload hardening (admission-enforced)

| Control | Implementing file | Frameworks |
|---|---|---|
| `require-run-as-nonroot` | `policies/workload-hardening/require-run-as-nonroot.yaml` | CIS EKS 5.2.1, NIST SSDF PS.1.1, PCI-DSS v4 6.4.1 |
| `require-readonly-rootfs` | `policies/workload-hardening/require-readonly-rootfs.yaml` | CIS EKS 5.2.5, NIST SSDF PS.1.1 |
| `drop-all-capabilities` | `policies/workload-hardening/drop-all-capabilities.yaml` | CIS EKS 5.2.9, NIST SSDF PS.1.1 |
| `disallow-privilege-escalation` | `policies/workload-hardening/disallow-privilege-escalation.yaml` | CIS EKS 5.2.10, NIST SSDF PS.1.1 |
| `require-seccomp-runtimedefault` | `policies/workload-hardening/require-seccomp-runtimedefault.yaml` | CIS EKS 5.7.2, NIST SSDF PS.1.1 |
| `disallow-host-namespaces` (hostNetwork/hostIPC/hostPID/hostPath/privileged) | `policies/workload-hardening/disallow-host-namespaces.yaml` | CIS EKS 5.2.2/5.2.3/5.2.4, NIST SSDF PS.1.1, SOC 2 CC6.1 |
| `require-resource-limits` | `policies/workload-hardening/require-resource-limits.yaml` | CIS EKS 5.7.3, NIST SSDF PS.1.1 |

## Governance and network isolation

| Control | Implementing file | Frameworks |
|---|---|---|
| `disallow-default-namespace` | `policies/governance/disallow-default-namespace.yaml` | CIS EKS 5.7.4, NIST SSDF PO.3.1 |
| `require-ownership-labels` | `policies/governance/require-ownership-labels.yaml` | SOC 2 CC7.2 (asset inventory), NIST SSDF PO.3.1 |
| `require-probes` | `policies/governance/require-probes.yaml` | SOC 2 CC7.2 (availability monitoring) |
| `default-deny-networkpolicy` (generated per namespace, C9) | `policies/generate/default-deny-networkpolicy.yaml` | CIS EKS 5.3.2, NIST SSDF PS.1.1, PCI-DSS v4 1.3 |
| `namespace-resourcequota` (generated per namespace) | `policies/generate/namespace-resourcequota.yaml` | CIS EKS 5.7.3, SOC 2 CC7.2 (availability) |
| Pod Security Admission `restricted` | `gitops/apps/demo-api/base/namespace.yaml`, `gitops/platform/verification/namespace.yaml` | CIS EKS 5.7.3, NIST SSDF PS.1.1 |

## GitOps and change management

| Control | Implementing file | Frameworks |
|---|---|---|
| Required review + CODEOWNERS before merge | `.github/CODEOWNERS`, branch ruleset (Phase 9) | SOC 2 CC8.1, NIST SSDF PO.3.1 |
| Signed commits required | Branch ruleset (Phase 9) | SOC 2 CC8.1 |
| Same policies enforced in CI (shift-left) and at admission — one source of truth (C8) | `.github/workflows/ci.yml`, `policies/` | NIST SSDF PW.7.2, SOC 2 CC7.1 |
| GitOps pull model — cluster never exposed to CI | `gitops/bootstrap/`, Argo CD Applications throughout `gitops/platform/` | SOC 2 CC6.1 |
| Drift detection + automatic self-heal | `gitops/platform/argocd/values.yaml` (`selfHeal: true`), demonstrated in `demo/attack/05-out-of-band-drift.sh` | SOC 2 CC7.1/CC7.2, CIS EKS 5.3 |
| Cluster-wide compliance visibility | `gitops/platform/policy-reporter/` | SOC 2 CC7.2 |

## Infrastructure as code

| Control | Implementing file | Frameworks |
|---|---|---|
| No `aws_iam_access_key` resource anywhere (C2) | `infra/terraform/policy/` (conftest rule + fail fixture) | NIST SSDF PS.1.1, SOC 2 CC6.1 |
| No wildcard IAM `Action: "*"` | `infra/terraform/policy/` (conftest rule + fail fixture) | NIST SSDF PS.1.1, CIS EKS 5.1, SOC 2 CC6.1 |
| Encryption at rest (S3, Secrets Manager, ECR) via KMS | `infra/terraform/modules/kms`, `modules/secrets`, `modules/ecr`, `modules/tfstate-backend` | PCI-DSS v4 3.5, SOC 2 CC6.1 |
| Static analysis (checkov, tflint) on every plan | `.github/workflows/iac-scan.yml` | NIST SSDF PW.7.2 |
