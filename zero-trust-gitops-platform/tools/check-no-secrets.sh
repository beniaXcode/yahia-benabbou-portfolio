#!/usr/bin/env bash
# Enforces C1 (zero GitHub Actions secrets besides GITHUB_TOKEN) and C3 (no
# private signing key ever committed). Run locally via pre-commit, and in CI
# by .github/workflows/verify-no-secrets.yml. Exits non-zero on any finding.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

echo "==> checking for GitHub Actions secrets other than GITHUB_TOKEN"
if [ -d "$root/../.github/workflows" ]; then
  matches="$(grep -rEn 'secrets\.[A-Za-z0-9_]+' "$root/../.github/workflows" 2>/dev/null \
    | grep -Ev 'secrets\.GITHUB_TOKEN\b' || true)"
  if [ -n "$matches" ]; then
    echo "FAIL: workflow(s) reference a secret other than GITHUB_TOKEN:"
    echo "$matches"
    fail=1
  fi
fi

echo "==> checking for tracked private-key / credential files"
tracked_keys="$(git -C "$root/.." ls-files -- '*.key' '*.pem' '*.p12' '*.pfx' 'cosign.key' '*kubeconfig*' '.env' '.env.*' 2>/dev/null || true)"
if [ -n "$tracked_keys" ]; then
  echo "FAIL: forbidden files are tracked in git:"
  echo "$tracked_keys"
  fail=1
fi

echo "==> checking working tree for AWS-access-key-shaped strings"
if command -v git >/dev/null 2>&1; then
  aws_hits="$(git -C "$root/.." grep -InE 'AKIA[0-9A-Z]{16}' -- . ':(exclude).gitleaks.toml' ':(exclude)zero-trust-gitops-platform/tools/check-no-secrets.sh' 2>/dev/null || true)"
  if [ -n "$aws_hits" ]; then
    echo "FAIL: AWS-access-key-shaped string found:"
    echo "$aws_hits"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "check-no-secrets: FAILED"
  exit 1
fi

echo "check-no-secrets: OK"
