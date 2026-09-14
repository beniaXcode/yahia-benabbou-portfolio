## What changed and why

<!-- Which phase (BRIEF.md §6) does this belong to? What problem does it solve? -->

## Which constraint(s) does this touch

<!-- C1-C10 from CLAUDE.md, if applicable. If this weakens or works around one of them, stop —
     don't open the PR; ask first. -->

## How this was verified

<!-- Exact commands run and their output — `make lint`, `make test`, `kyverno test`, `terraform
     plan` + `conftest test`, etc. "Should work" is not verification. -->

## ADR

<!-- Link the ADR if this adds a dependency or makes an architectural decision. -->

## Checklist

- [ ] No `TODO`/`TBD`/`FIXME`/placeholder content
- [ ] No new GitHub Actions secret added (besides the automatic `GITHUB_TOKEN`)
- [ ] Every new Kyverno policy has both a passing and a failing test fixture
- [ ] Every new/changed GitHub Action is pinned to a commit SHA
- [ ] Docs updated alongside the code that needed them (not in a follow-up PR)
