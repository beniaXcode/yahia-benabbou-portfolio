#!/usr/bin/env bash
# Plans every fixture under tests/{pass,fail}/ and runs conftest against
# the resulting plan JSON, asserting pass fixtures are allowed and fail
# fixtures are denied. Used by `make policy-test` and by CI's
# iac-scan.yml (Phase 4+). Requires `terraform` and `conftest` on PATH.
set -euo pipefail

policy_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail=0

run_fixture() {
  local dir="$1" expect="$2"
  local name
  name="$(basename "$dir")"
  local planfile="$tmpdir/${expect}-${name}.tfplan"
  local jsonfile="$tmpdir/${expect}-${name}.json"

  terraform -chdir="$dir" init -input=false >/dev/null
  terraform -chdir="$dir" plan -input=false -out="$planfile" >/dev/null
  terraform -chdir="$dir" show -json "$planfile" >"$jsonfile"

  if conftest test "$jsonfile" -p "$policy_dir" >"$tmpdir/${expect}-${name}.out" 2>&1; then
    result="pass"
  else
    result="fail"
  fi

  if [ "$result" != "$expect" ]; then
    echo "MISMATCH: fixture '$name' expected to $expect conftest, but it $result"
    cat "$tmpdir/${expect}-${name}.out"
    fail=1
  else
    echo "OK: $expect fixture '$name' -> conftest $result"
  fi
}

for dir in "$policy_dir"/tests/pass/*/; do
  [ -d "$dir" ] || continue
  run_fixture "${dir%/}" pass
done
if [ -f "$policy_dir/tests/pass/main.tf" ]; then
  run_fixture "$policy_dir/tests/pass" pass
fi

for dir in "$policy_dir"/tests/fail/*/; do
  [ -d "$dir" ] || continue
  run_fixture "${dir%/}" fail
done

if [ "$fail" -ne 0 ]; then
  echo "policy fixture tests: FAILED"
  exit 1
fi

echo "policy fixture tests: OK"
