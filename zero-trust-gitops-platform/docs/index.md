# zero-trust-gitops-platform

A reference implementation of GitOps delivery on AWS EKS with zero long-lived credentials,
cryptographically attested images, and policy-enforced admission.

**The question this repository answers:** *how does code reach production without anyone holding a
permanent key?*

Start with [Architecture](architecture.md) for the trust chain end to end, or jump straight to the
[Threat Model](threat-model.md) for the six attack scenarios this platform is built to stop.

## Map

| Section | What's there |
|---|---|
| [Architecture](architecture.md) | The trust chain, trust boundaries, the two properties that make this zero-trust |
| [Identity model](identity-model.md) | GitHub OIDC → AWS STS, Sigstore keyless, EKS Pod Identity — every credential exchange in the system |
| [Supply chain](supply-chain.md) | Build → SBOM → sign → attest → promote → admit → continuously re-verify |
| [Threat model](threat-model.md) | STRIDE per trust boundary, six attacker scenarios, what would actually break this |
| [Compliance mapping](compliance-mapping.md) | Every control mapped to NIST SSDF, SLSA v1.0, CIS EKS, SOC 2, PCI-DSS v4 |
| [Policy catalog](policy-catalog.md) | Every Kyverno policy, generated from `policies/` itself |
| [Versions](versions.md) | Every pinned tool/chart/image version and exactly how it was resolved |
| [Fidelity](fidelity.md) | What this build environment could and couldn't verify for real, phase by phase |
| [ADRs](adr/0001-ghcr-over-ecr-for-this-deployment.md) | The six architectural decisions and why |
| [Runbooks](runbooks/policy-violation-triage.md) | What to do when a policy fires, a sync fails, or a signing identity looks compromised |
