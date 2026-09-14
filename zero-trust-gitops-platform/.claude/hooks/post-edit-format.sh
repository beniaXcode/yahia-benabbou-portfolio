#!/usr/bin/env bash
# PostToolUse hook (Write|Edit). Auto-formats the file that was just touched.
# Best-effort: a missing formatter is skipped, never a hard failure, since
# not every tool is guaranteed to be installed in every environment this
# project is developed from.
set -uo pipefail

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // ""')"
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

case "$file_path" in
  *.tf)
    command -v terraform >/dev/null 2>&1 && terraform fmt "$file_path" >/dev/null 2>&1
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file_path"
    ;;
  *.yaml|*.yml)
    if command -v yamlfmt >/dev/null 2>&1; then
      yamlfmt "$file_path" >/dev/null 2>&1
    fi
    ;;
  *.md|*.json)
    command -v prettier >/dev/null 2>&1 && prettier --write "$file_path" >/dev/null 2>&1
    ;;
esac

exit 0
