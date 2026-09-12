# Lightweight Threat Model Template

Used for architecturally significant changes — a new service boundary, a new external
integration, a new trust relationship. Deliberately short: the goal is a 30-minute working
session with the owning team, not a document nobody finishes.

## 1. What are we building?

One paragraph. What does this change do, and what does it talk to?

## 2. What can go wrong? (STRIDE, applied lightly)

| Category | Question | Applies? | Notes |
|---|---|---|---|
| Spoofing | Can something impersonate a legitimate caller? | | |
| Tampering | Can data be modified in transit or at rest without detection? | | |
| Repudiation | Can an action happen without an audit trail? | | |
| Information disclosure | Can this expose data to someone who shouldn't see it? | | |
| Denial of service | Can this be made unavailable by a bad actor or by load? | | |
| Elevation of privilege | Can a caller do more than their role should allow? | | |

## 3. Existing controls

What already mitigates each "applies" row above (IAM policy, network policy, mTLS, input
validation, rate limiting)?

## 4. Gaps and remediation

For each unmitigated risk: owner, severity, and target date. This becomes a tracked issue per the
remediation workflow in the main README — not a document that sits unread.

## 5. Sign-off

Reviewed with: (owning team lead) + (security). Dated.
