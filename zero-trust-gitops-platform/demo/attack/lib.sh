#!/usr/bin/env bash
# Shared by every demo/attack/*.sh script. Never run standalone.
#
# The contract every script in this directory follows: attempt something
# real, print exactly one EXPECTED/ACTUAL pair, and exit 0 only if the
# attack was correctly blocked — exit non-zero (the attack "succeeding")
# is the failure mode `make demo-attack` and CI both have to catch.
set -euo pipefail

NAMESPACE="${NAMESPACE:-demo-api-dev}"

# expect_denied <description> -- <command...>
# Runs the command; a non-zero exit (kubectl/API rejects it, or the thing
# it tried to do never took effect) means the attack was blocked, which is
# the outcome this whole repo is built to produce.
expect_denied() {
  local description="$1"
  shift
  # allow the caller's own `-- ` separator for readability
  [ "${1:-}" = "--" ] && shift

  echo "EXPECTED: DENIED ($description)"
  if actual_output="$("$@" 2>&1)"; then
    echo "ACTUAL:   NOT DENIED — the command below succeeded, which means the attack worked"
    echo "$actual_output"
    return 1
  fi
  echo "ACTUAL:   DENIED"
  echo "$actual_output" | sed 's/^/          /'
  return 0
}

cleanup_resource() {
  kubectl -n "$NAMESPACE" delete --ignore-not-found --wait=false "$@" >/dev/null 2>&1 || true
}
