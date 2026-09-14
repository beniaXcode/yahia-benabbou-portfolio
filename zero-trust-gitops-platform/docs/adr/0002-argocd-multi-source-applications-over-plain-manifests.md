# 0002. Argo CD multi-source Applications over plain Helm-values or raw manifests

Status: Accepted

## Context

Each platform component in `gitops/platform/` (Argo CD itself, Kyverno, Policy Reporter, External
Secrets Operator, metrics-server) needs three independent things tracked in Git: a pinned upstream
Helm chart, this repository's own values for it, and — for Kyverno specifically — the actual
`policies/` ClusterPolicy objects that need to reach the cluster as plain manifests, not Helm
values. A single-source Application can point at exactly one of those.

## Decision

Every platform component is a multi-source Argo CD `Application`: one source is the upstream Helm
chart pinned by exact chart version (not merely app version — `docs/versions.md` documents why
those differ and how each was resolved), a second source is this repository at a `ref: values`
alias supplying `$values/.../values.yaml`, and — where a component needs it (Kyverno's policies,
External Secrets' `ClusterSecretStore`) — a third source pointing at a `manifests/` subdirectory
kept separate from `application.yaml`/`values.yaml` themselves.

## Consequences

Chart version, this repository's own values, and any extra plain manifests each get their own
diffable, independently-reviewable file, instead of one `Application` manifest that either inlines
everything (losing the separation between "upstream pin" and "our config") or a single directory
source that Argo CD would try to apply *every* file in as a raw manifest, `application.yaml` and
`values.yaml` included — verified as a real failure mode, not assumed, when
`gitops/platform/kyverno/local-key-attestor/`'s own kustomization had to move out of `policies/`
after `kustomize build` reported "cycle detected" for exactly this shape of directory-inside-its-own-base
mistake. The cost is more files per component (four instead of one) and a source list that has to
stay in sync by hand — Argo CD does not validate that a `manifests/` path actually contains only
what's intended; a stray file there is caught only by `kyverno apply`/manual review, not by the
Application definition itself.
