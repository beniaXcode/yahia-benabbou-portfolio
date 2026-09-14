# Threat model

Per trust boundary from [`architecture.md`](architecture.md#trust-boundaries): a STRIDE pass, then
six concrete attacker scenarios, then the honest list of what still breaks this.

## STRIDE per trust boundary

| Boundary | Spoofing | Tampering | Repudiation | Information Disclosure | Denial of Service | Elevation of Privilege |
|---|---|---|---|---|---|---|
| Developer ↔ GitHub | Signed commits (GPG/SSH) required by the branch ruleset — an unsigned commit is rejected, not just flagged | Required review + CODEOWNERS means no single account merges unreviewed | Signed commits + GitHub's own audit log; every merge is attributable | Repository is public by design (this is a portfolio piece) — no secret ever lives here to disclose (C1, C7) | Not addressed by this platform — GitHub's own DoS protections apply | A reviewer approving a PR is the only path to merge; CODEOWNERS scopes who that can be |
| GitHub Actions ↔ AWS | OIDC token's `sub`/`aud` claims are pinned per role (C6) — a token from a different repo or ref cannot assume this role | The role's permissions are scoped to push-to-one-registry; nothing it can reach can be tampered with beyond that | CloudTrail logs every `AssumeRoleWithWebIdentity` and subsequent AWS call against the token's own claims | The token is short-lived and never logged; the session it mints expires within minutes of the job ending | A compromised runner can exhaust its own session's rate limits, not AWS account-wide resources | The trust policy's exact-match `sub` condition is the only thing standing between "this workflow" and "any workflow" — see scenario 1 |
| GitHub Actions ↔ Sigstore | Fulcio issues a certificate binding the OIDC identity to the signing key it generates for that one operation | A signature cannot be forged without either that OIDC identity or a Sigstore compromise (see "what would actually break this") | Rekor's transparency log is public and append-only — every signature is independently checkable | Nothing sensitive crosses this boundary; Fulcio/Rekor are public-good infrastructure by design | Public-good Sigstore rate limits could delay a build; no confidentiality or integrity impact | N/A — Fulcio does not grant any privilege beyond "produced a certificate for this identity" |
| Git repo ↔ Argo CD | Argo CD authenticates the repository by URL/known host, pulling over HTTPS/SSH | Any tampering with `gitops/` is a tampering with the Git repository itself, covered by the boundary above | Argo CD's own sync history (`kubectl -n argocd get application <name> -o yaml`) records every revision applied | Argo CD holds no cluster-external secrets for this pull | A repository outage delays reconciliation; `selfHeal` resumes once it recovers | Argo CD's own RBAC (`role:readonly` default — `gitops/platform/argocd/values.yaml`) scopes who can trigger a manual sync or view secrets |
| Argo CD ↔ Kubernetes API | Argo CD's own in-cluster ServiceAccount, scoped by its Helm chart's RBAC | Every apply still goes through the same admission chain as any other client (see next boundary) | The Kubernetes API server's own audit log covers this, independent of Argo CD | Argo CD can read Secrets it manages; scoped by its own RBAC, not broadened by this platform | A reconciliation storm is bounded by `timeout.reconciliation` and the controller's own concurrency limits | Argo CD's ServiceAccount is not cluster-admin; it can only write what its RBAC permits |
| Admission controller ↔ workload | Kyverno's `verifyImages` binds admission to a specific signer identity, not merely "signed" (scenario 4) | Kyverno cannot be bypassed by any API write — it is a validating admission webhook, not opt-in | Kyverno's `PolicyReport` objects (surfaced by Policy Reporter) record every evaluation, pass or fail | Kyverno's own webhook has no access to workload secrets it isn't already granted by RBAC | An admission webhook that times out fails closed for `Enforce` policies (default `failurePolicy`) | Kyverno enforces `restricted`-equivalent pod security regardless of who submitted the manifest |
| Workload ↔ AWS | Pod Identity binds a ServiceAccount, not a node, to a role — no workload can assume another's identity | An IAM role scoped to one Secrets Manager path cannot tamper with anything outside it | CloudTrail logs every AWS call a Pod Identity session makes, attributable to that specific workload | A workload with no Pod Identity association has no AWS credentials to disclose, and IMDSv2 + hop limit 1 stop it from reaching node-role credentials instead (scenario 6) | Default-deny egress NetworkPolicy limits what a compromised workload can even attempt to reach | A workload's IAM role is exactly what its Terraform-defined policy grants — no node-role inheritance |

## Six attacker scenarios

Each: **attack → what the attacker gains without this platform → the control that stops it here →
the file that implements it → residual risk.**

### 1. Stolen CI token / compromised GitHub Action

A malicious third-party action in the build workflow exfiltrates everything available to the
runner.

**Without this platform:** a long-lived `AWS_ACCESS_KEY_ID` sitting in repository secrets means
persistent, standing access to the AWS account — usable indefinitely, from anywhere, until someone
notices and rotates it.

**Here:** the only credential ever present is a short-lived STS session, scoped to one role, minted
from an OIDC assertion that is itself audience-bound (`aud=sts.amazonaws.com`) and only
exchangeable for a role whose trust policy pins the exact `sub` claim (`repo:<org>/<repo>:ref:<ref>`
or `:environment:<env>` — never a wildcard, C6).

**Implemented in:**
[`infra/terraform/modules/github-oidc-provider`](https://github.com/beniaXcode/yahia-benabbou-portfolio/tree/main/zero-trust-gitops-platform/infra/terraform/modules/github-oidc-provider),
[`.github/workflows/build-sign-attest.yml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/.github/workflows/build-sign-attest.yml).

**Residual risk:** an attacker with runner execution *during* that job still has that session's
permissions for its lifetime — push access to this project's own image repository. That is exactly
why the role's own IAM policy is scoped to that one repository and nothing else: the blast radius
of a compromised job is bounded to "can push a bad image," which the next control (admission-time
signature verification) still catches once anyone tries to deploy it.

### 2. Malicious insider commit

An author with legitimate merge rights commits a deliberately harmful change.

**Controls:** required review via CODEOWNERS, signed commits, and — critically — the admission
gate verifies the *build identity*, not the commit's intent. A merged malicious change still
produces an image built by the expected workflow, correctly signed, correctly attested, and is
subject to every other policy (resource limits, no privilege escalation, registry allowlist) the
same as any other deploy.

**Implemented in:** `.github/CODEOWNERS`, the branch ruleset (Phase 9),
[`policies/supply-chain/verify-image-signature.yaml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/policies/supply-chain/verify-image-signature.yaml).

**What this does not stop:** a reviewer who approves a genuinely malicious change, or a change that
is malicious in a way no policy in this repository checks for (a logic bug, an intentional data
exfiltration path built into the application itself). This platform verifies *supply chain*
integrity — who built what, and that the runtime environment is hardened — not code review
quality or application-level correctness.

### 3. Compromised base image / dependency

An upstream base image or Go module is compromised after this repository last built against it.

**Controls:** digest-pinned base images (never a mutable tag — `apps/demo-api/Dockerfile`), an SBOM
attestation recording exactly what's in the image, a grype vulnerability gate on every build, a
scheduled re-verification CronJob that keeps checking already-running images, and Dependabot
alerts/updates on `go.mod` and the Dockerfile.

**Implemented in:** `apps/demo-api/Dockerfile`, `.github/workflows/build-sign-attest.yml` (syft +
grype steps), `gitops/platform/verification/cronjob.yaml`, `.github/dependabot.yml`.

**Residual risk:** a compromise that predates this repository's own dependency resolution (a
poisoned package published *before* it was pinned) is caught only if grype's vulnerability
database or a later audit flags it — not prevented at pin time.

### 4. Registry compromise / image substitution

An attacker gains write access to the image registry and replaces a tag's content, or pushes a
malicious image under a name that looks legitimate.

**Controls:** immutable tags plus digest-only references mean a tag can't be silently repointed
underneath a running deployment (C5); signature verification at admission means even a
successfully substituted image cannot produce a valid Fulcio certificate binding it to this
project's release workflow.

**Implemented in:**
[`infra/terraform/modules/ecr`](https://github.com/beniaXcode/yahia-benabbou-portfolio/tree/main/zero-trust-gitops-platform/infra/terraform/modules/ecr) (production; `IMMUTABLE` tags, a
repository policy scoping push to the `build` role only),
[`policies/supply-chain/require-image-digest.yaml`](https://github.com/beniaXcode/yahia-benabbou-portfolio/blob/main/zero-trust-gitops-platform/policies/supply-chain/require-image-digest.yaml),
`verify-image-signature.yaml`.

**Residual risk:** an attacker who compromises the registry account itself (not just a tag) could
still *delete* an image, causing a denial of service, even though they cannot make Kyverno accept
a substitute.

### 5. Leaked kubeconfig / direct cluster access

An attacker obtains a kubeconfig or otherwise gets `kubectl` access to the cluster directly,
bypassing GitOps entirely.

**Controls:** admission policies apply to *all* API writes regardless of actor — there is no
"trusted path" that skips Kyverno. Argo CD's `selfHeal: true` reverts any out-of-band change within
one reconciliation interval (demonstrated in `demo/attack/05-out-of-band-drift.sh`). EKS access
entries (not the legacy `aws-auth` ConfigMap) plus CloudTrail/API-server audit logging record who
did what.

**Implemented in:** every policy under `policies/` (admission applies regardless of caller),
`gitops/platform/argocd/values.yaml` (`selfHeal`), `infra/terraform/modules/eks` (access entries).

**Residual risk:** a cluster-admin-scoped identity can disable Kyverno itself, or delete the Argo
CD Application that would otherwise revert their change. Detection path: Policy Reporter's
cluster-wide compliance report would show the policy engine going silent, and Argo CD's own
`root-platform` Application (which manages Kyverno's own Helm release) would show drift the moment
anyone tried to remove it out of band — the same self-heal loop that protects `demo-api` protects
the platform's own control plane.

### 6. Exfiltration from a running pod

A compromised or malicious workload tries to reach AWS credentials it was never granted.

**Controls:** IMDSv2 with hop limit 1 (`infra/terraform/modules/eks`'s node launch template)
defeats node-role credential theft even from a process that can reach the metadata service at all;
EKS Pod Identity scopes each workload's own role, with no fallback to node-role inheritance;
default-deny egress NetworkPolicy (generated per namespace, C9) means most workloads cannot even
open a connection to try; read-only root filesystem and dropped capabilities limit what a
compromised process can do once running.

**Implemented in:** `infra/terraform/modules/eks` (launch template), `infra/terraform/modules/pod-identity`,
`policies/generate/default-deny-networkpolicy.yaml`,
`policies/workload-hardening/require-readonly-rootfs.yaml`, `drop-all-capabilities.yaml`.

**Residual risk, and an honest fidelity note:** `demo/attack/06-exfiltrate-node-role.sh` proves the
NetworkPolicy half of this on the local `kind` demo — it cannot prove the IMDSv2/hop-limit half at
all, because a `kind` node is a Docker container, not an EC2 instance, and has no instance-metadata
service to test against. That half is validated by `infra/terraform/modules/eks`'s own Terraform
tests and its `checkov`/`tflint` results (Phase 2), not by anything the kind demo can exercise —
see [`fidelity.md`](fidelity.md).

## What would actually break this

Being honest about the attack paths this platform does not defend against, because a threat model
that only lists what it stops is marketing, not analysis:

- **Compromise of the Sigstore public-good instance itself** (Fulcio's root CA, or Rekor's log
  integrity). This platform trusts Sigstore's public infrastructure the same way it trusts GitHub's
  and AWS's — a compromise there is outside this repository's control. A real production deployment
  handling higher-stakes workloads might run a private Sigstore instance instead
  (`sigstore/scaffolding`), trading the public transparency-log benefit for reduced blast radius
  from a shared-infrastructure compromise.
- **A malicious maintainer with repository admin rights.** Branch rulesets, required review, and
  CODEOWNERS all assume the person configuring them isn't themselves the attacker. Repository
  admin can disable a ruleset, add themselves as a bypass actor, or change CODEOWNERS. Mitigation
  in a real org: require organization-owner approval (not repo-admin) to modify branch protection,
  and log every settings change to a SIEM outside the attacker's own control.
- **Supply-chain compromise of Kyverno itself.** If the Kyverno image or Helm chart this repository
  pulls were compromised upstream, the admission controller enforcing every other control here
  would be the thing doing the compromising. Mitigation: pin Kyverno by chart version and verify
  its own provenance the same way this repository verifies `demo-api`'s (Kyverno itself publishes
  signed images); this repository does not yet do that for its own platform components — a real
  gap, not glossed over.
- **AWS account root.** Root credentials bypass every IAM boundary this platform relies on. Out of
  scope for a repository-level control; mitigated organizationally (root MFA hardware key, root
  credentials never used day-to-day, AWS Organizations SCPs).
