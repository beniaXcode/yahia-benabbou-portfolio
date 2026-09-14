# Zero-Trust GitOps Reference Platform

This branch is different from the others in this repo: it isn't a write-up of a past client
engagement, it's a working reference platform I built to answer one question mechanically, not
just describe it — *how does code reach production without any human or machine holding a
permanent key?*

The full platform — GitHub OIDC to AWS STS, keyless Sigstore signing, SLSA provenance, and
Kyverno admission control that re-verifies all of it before a workload ever runs — lives in
[`zero-trust-gitops-platform/`](zero-trust-gitops-platform/README.md), self-contained with its own
README, `Makefile`, docs, and CI.

— Yahia Benabbou, Senior DevSecOps & Cloud Security Engineer, Rabat, Morocco.
[profile.nearvic.com](https://profile.nearvic.com) · [nearvic.com](https://nearvic.com)
