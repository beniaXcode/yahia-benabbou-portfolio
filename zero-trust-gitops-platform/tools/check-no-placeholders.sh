#!/usr/bin/env bash
# Operating Rule 6 / BRIEF.md's Definition of Done: no TODO, TBD, FIXME, or
# lorem-ipsum text anywhere in committed work. Run locally via pre-commit,
# and in CI by .github/workflows/ci.yml.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$root/.." && pwd)"

# CLAUDE.md and the PR template both *state* this rule in prose; ci.yml's
# own step name and this hook's own pre-commit entry both *name* this check
# by what it looks for. Excluding these specific, known lines by name, not
# by weakening the pattern, is what keeps this check meaningful everywhere
# else — the same principle as check-no-secrets.sh's own self-referential
# exclusion.
matches="$(grep -rniE 'TODO|TBD|FIXME|lorem ipsum' "$repo_root" \
  --include='*.md' --include='*.yaml' --include='*.yml' --include='*.go' \
  --include='*.sh' --include='*.tf' \
  --exclude-dir='.git' --exclude-dir='node_modules' --exclude-dir='site' \
  2>/dev/null \
  | grep -Ev '/CLAUDE\.md:|/pull_request_template\.md:|/check-no-placeholders\.sh:|/ci\.yml:.*Check for TODO|/\.pre-commit-config\.yaml:.*TODO' \
  || true)"

if [ -n "$matches" ]; then
  echo "check-no-placeholders: FAILED — found placeholder markers in committed work:"
  echo "$matches"
  exit 1
fi

echo "check-no-placeholders: OK"
