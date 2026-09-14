**zero-trust-gitops-platform** is a reference implementation of GitOps delivery on AWS EKS built
around one question: how does code reach production without anyone holding a permanent key?

GitHub Actions exchanges a short-lived OIDC token for AWS credentials that expire in minutes — no
static access keys anywhere. Every image is signed keylessly with Sigstore (Fulcio issues a
certificate binding the signature to the exact build workflow) and carries an SLSA Build L3
provenance attestation, both logged to a public transparency log. Argo CD pulls from Git — the
cluster is never exposed to CI — and Kyverno independently re-verifies signature, provenance, and
pod hardening at admission before anything runs, rather than trusting that CI did its job.

Six attack scripts prove it: an unsigned image, a mutable tag, a privileged pod, an image signed by
the wrong identity, out-of-band cluster drift, and a credential-theft attempt from an unprivileged
pod — each one demonstrably blocked.

Repo: github.com/beniaXcode/yahia-benabbou-portfolio/tree/main/zero-trust-gitops-platform
