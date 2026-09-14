# 0006. Local demo fidelity fallbacks: key-based signing, no Falco/Tetragon

Status: Accepted

## Context

Two parts of this platform's design assume real infrastructure `make demo`'s local `kind` cluster
does not have: keyless signing needs Fulcio/Rekor reachable, and BRIEF.md's optional runtime
detection module (Falco or Tetragon) needs a real kernel and cluster to tune and validate eBPF
rules against — building either out for the local demo risked either a fragile approximation
nobody could verify, or a real dependency this sandbox's own tooling (no Docker, no kind) could
never have tested before committing it.

## Decision

**Signing:** BRIEF.md's own local-signing-fidelity contingency names `sigstore/scaffolding`
(a local Fulcio/Rekor/CTLog/Trillian stack) as preferred, "attempt it first," with a documented
fallback — a demo-only ephemeral key pair, never committed, with Kyverno switched to a `keys`
attestor. Scaffolding was evaluated and set aside: its own design targets CI test fixtures, not a
lightweight `make demo` loop, and stands up several long-running services whose TLS/trust-root
bootstrapping this sandbox has no way to iterate on and verify. The fallback was implemented
instead: `demo/up.sh` generates an ephemeral cosign key pair fresh on every run, signs the
locally-built image with it (`--tlog-upload=false`, keeping the whole path offline), and
`gitops/platform/kyverno/local-key-attestor/` patches the three `verifyImages` policies from a
keyless (Fulcio) attestor to a `keys` attestor pinned to that key's public half, published as a
Kubernetes Secret the overlay references by name.

**Runtime detection:** Falco/Tetragon is not implemented. BRIEF.md marks this module explicitly
optional; unlike every other component in `gitops/platform/`, which at least renders and validates
offline via `kustomize build` and `kyverno apply`, an eBPF-based detection tool produces
untested Helm values with no way to catch a wrong one before it reaches a real cluster.

## Consequences

Attack 4 (`demo/attack/04-wrong-signer-identity.sh`) demonstrates "Kyverno checks *who* signed"
using a second, unregistered key pair rather than a mismatched Fulcio certificate identity — the
same underlying mechanism, adapted to the fallback, documented explicitly in that script rather
than silently treated as identical to the production keyless flow. A reviewer running the real
production configuration (a Fulcio-reachable cluster, `path: zero-trust-gitops-platform/policies`
restored in `gitops/platform/kyverno/application.yaml`'s third source) gets the actual keyless
behavior this platform is built around; the local demo proves the *admission logic* — reject an
untrusted signer — without proving the *keyless mechanism* specifically. Runtime detection
(anomalous process execution, unexpected network connections from a container) is not demonstrated
anywhere in this repository — a real gap, tracked here rather than glossed over, and the clearest
concrete next step for anyone extending this platform on a machine with Docker.
