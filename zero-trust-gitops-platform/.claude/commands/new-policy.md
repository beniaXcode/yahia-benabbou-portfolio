---
name: new-policy
description: Scaffold a new Kyverno policy with both test fixtures and a catalog entry
argument-hint: "[policy-name]"
---

Scaffold a new Kyverno policy named `$1` (kebab-case, e.g. `require-probes`) in the right
subdirectory of `policies/` (`supply-chain/`, `workload-hardening/`, `governance/`, or
`generate/` — infer from the name and description given, or ask).

Do all of this in one pass:

1. Write `policies/<category>/$1.yaml` starting in `validationFailureAction: Audit` (never
   `Enforce` on first write — that maturity step is a deliberate, separate change once the policy
   has been observed against real traffic). Include the full annotation block required by
   `CLAUDE.md`/BRIEF.md §7.1: `policies.kyverno.io/title`, `category`, `severity`, `subject`,
   `description`, plus the two custom annotations `nearvic.io/rationale` (the specific attack this
   policy prevents — one or two concrete sentences, not a restatement of the rule) and
   `nearvic.io/compliance` (which mapped controls from `docs/compliance-mapping.md` this satisfies).
2. Write `policies/tests/$1/kyverno-test.yaml` plus at least one passing and one failing resource
   fixture in the same directory. Never write a policy without both.
3. Run `kyverno test policies/tests/$1/` and show the output — it must pass before you're done.
4. Run `make policy-catalog` to regenerate `docs/policy-catalog.md` and confirm the new entry
   appears correctly.

Refuse to relax the policy's rule to make a fixture pass — if a fixture doesn't behave as
expected, the fixture or the policy logic is wrong; fix whichever one is actually wrong.
