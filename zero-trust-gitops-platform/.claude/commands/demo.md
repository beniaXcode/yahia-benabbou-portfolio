---
name: demo
description: Bring up kind, bootstrap the GitOps loop, optionally run the attack suite, tear down
argument-hint: "[attack]"
---

Run the local demo end to end:

1. `make demo` — bring up `kind`, bootstrap Argo CD + Kyverno + the platform apps, and wait until
   every Application is `Synced` and `Healthy`.
2. If `$1` is `attack`, also run `make demo-attack` and show the pass/fail line for each of the
   six scenarios.
3. Tear down cleanly afterward (`make clean`) unless I say to leave it running — don't leave a
   `kind` cluster or port-forwards behind silently.

If any step doesn't converge in a reasonable time, show me the actual `kubectl get applications`
/ `kubectl get pods -A` output rather than guessing at what's wrong.
