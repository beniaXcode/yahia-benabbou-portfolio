#!/usr/bin/env bash
# PreToolUse hook (Write|Edit). Makes C1/C3 impossible to violate by
# accident: blocks the write instead of merely flagging it after the fact.
# Claude Code hook contract: JSON on stdin, exit 2 + stderr message blocks
# the tool call, exit 0 allows it.
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""')"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // ""')"

case "$tool_name" in
  Write) content="$(echo "$input" | jq -r '.tool_input.content // ""')" ;;
  Edit) content="$(echo "$input" | jq -r '(.tool_input.new_string // "") + "\n" + (.tool_input.old_string // "")')" ;;
  *) exit 0 ;;
esac

block() {
  echo "BLOCKED by pre-write-secret-guard: $1" >&2
  echo "File: $file_path" >&2
  exit 2
}

if echo "$content" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  block "content matches an AWS access key ID (AKIA...). C1/C2: no static AWS credentials in this repo."
fi

if echo "$content" | grep -qE -- '-----BEGIN (ENCRYPTED SIGSTORE|EC|RSA|OPENSSH|PRIVATE) KEY-----'; then
  block "content matches a private-key PEM header. C3: signing here is keyless — no private key is ever committed."
fi

if echo "$content" | grep -qE 'client-(key|certificate)-data:'; then
  block "content matches a kubeconfig client-certificate block. Kubeconfigs are never committed."
fi

if [[ "$file_path" == *".github/workflows/"*.yml || "$file_path" == *".github/workflows/"*.yaml ]]; then
  bad="$(echo "$content" | grep -oE 'secrets\.[A-Za-z0-9_]+' | grep -vx 'secrets\.GITHUB_TOKEN' | sort -u | tr '\n' ' ' || true)"
  if [ -n "$bad" ]; then
    block "workflow references a secret other than GITHUB_TOKEN ($bad). C1: this repo has zero Actions secrets besides the automatic GITHUB_TOKEN."
  fi
fi

exit 0
