# One CI/CD platform, 30+ services, no more "it works on my team's pipeline"

**Onclusive — Senior DevSecOps Engineer, 2026**

When I picked this up, every team had built its own pipeline. Some were good. Most were whatever
got a service shipped under deadline pressure two years ago and never got revisited. New hires
learned a different toolchain for every service they touched, and there was no consistent security
gate anywhere — a team could ship straight to production without a single automated check if their
pipeline just didn't have one wired in.

I didn't try to sell anyone on a rewrite. I built one templated pipeline, made it genuinely easier
to use than what people already had, and let adoption do the arguing for me.

## What it does

Every one of the 30+ microservices on this platform now runs through the same path: build, test,
SAST (SonarQube), dependency and container scanning (Trivy), a Terraform plan check on any infra
change, then GitOps delivery through ArgoCD. No team hand-writes deploy scripts anymore, and no
merge reaches `main` with an unresolved Critical or High finding — that's not a policy on a wiki,
it's a status check that blocks the merge button.

```mermaid
flowchart LR
    Dev[Developer push] --> CI[GitHub Actions]
    CI --> SAST[SonarQube]
    CI --> SCA[Dependency scan]
    CI --> IMG[Container scan]
    CI --> IAC[Terraform plan]
    SAST --> Gate{Gate}
    SCA --> Gate
    IMG --> Gate
    IAC --> Gate
    Gate -- pass --> ArgoCD
    Gate -- fail --> Owner[Back to the owning team, with severity attached]
    ArgoCD --> Cluster[OpenShift]
    Cluster --> Obs[Prometheus / Grafana / ELK]
```

## The part I actually spent time on

Anyone can bolt a scanner onto a pipeline. The work was in what happens *after* the scanner fires.
Early on, findings went into a shared security backlog and nobody with the context to fix them
ever looked at it. I rebuilt the routing so a finding lands directly on the team that owns the
code, tagged with severity, with a self-service Terraform module and Helm chart already available
so fixing it doesn't mean waiting on a platform-team ticket. That's the difference between a gate
people route around and a gate people actually use.

`scripts/ci-pipeline.yml` is the shape of the templated workflow every service runs. `scripts/argocd-app.yaml`
is the delivery side. `scripts/platform.tf` is how the shared registry, runners, and cluster
namespaces got provisioned — as code, reviewed like everything else.

## What changed

Deployment frequency went up **60%** — teams ship more often once they're not each maintaining
their own broken pipeline. Production incidents dropped **45%**. Vulnerabilities that used to
reach production and get caught later now get caught pre-merge **95%** of the time, and the
volume actually reaching production is down **80%**. Onboarding a new engineer onto a service went
from "learn this team's specific pipeline" to "read the shared doc" — **50%** faster.

None of that happened because the tools were clever. It happened because the gate was fast enough
and the routing was clear enough that people stopped treating security as something separate from
shipping.

*Same platform, cut two other ways: [`02-devsecops-shift-left`](../02-devsecops-shift-left) is the
program and process side of the security gates; [`03-kubernetes-workload-hardening`](../03-kubernetes-workload-hardening)
is what happens once a workload is actually running on the cluster.*
