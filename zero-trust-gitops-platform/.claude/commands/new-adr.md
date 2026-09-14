---
name: new-adr
description: Create the next-numbered ADR from the template with status Proposed
argument-hint: "[title]"
---

Create the next Architecture Decision Record for: $1

1. Look at `docs/adr/` and find the highest existing `NNNN-*.md` number; the new one is that
   number + 1, zero-padded to 4 digits.
2. Copy the structure of `docs/adr/0000-template.md` into `docs/adr/<NNNN>-<kebab-case-title>.md`.
3. Fill in Context, Decision, and Consequences from what you and I have actually discussed in
   this conversation — do not invent a rationale that wasn't part of the real discussion.
4. Set `Status: Proposed`. Never write `Status: Accepted` yourself; that's a human call.
5. If this ADR reverses or supersedes an earlier one, update that earlier ADR's `Status` line to
   `Superseded by NNNN` rather than deleting it.
