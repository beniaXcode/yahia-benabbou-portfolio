---
name: threat-review
description: STRIDE-review a changed component via the threat-modeler subagent
argument-hint: "[path]"
---

Have the `threat-modeler` subagent do a STRIDE review of `$1` and propose a diff against
`docs/threat-model.md`.

Give the subagent: what changed in `$1` and why, which trust boundary (see BRIEF.md §3.2 / the
current `docs/threat-model.md`) this component sits on, and the existing six attacker scenarios so
it can say whether this change affects any of them. Ask it to return a proposed `docs/threat-model.md`
diff, not to edit the file itself — you review the diff before applying it.
