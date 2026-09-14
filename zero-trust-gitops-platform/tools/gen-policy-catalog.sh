#!/usr/bin/env bash
# Regenerates docs/policy-catalog.md from every policy's own annotations —
# never hand-edit that file. Run via `make policy-catalog`. CI (Phase 4+)
# fails the build if the committed file differs from this script's output,
# so the catalog can't drift from the policies it describes.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policies_dir="$root/policies"
out="$root/docs/policy-catalog.md"

{
  echo "# Policy catalog"
  echo
  echo "**Generated from the annotations on every file in \`policies/\` by"
  echo "\`tools/gen-policy-catalog.sh\` — do not hand-edit.** Run \`make"
  echo "policy-catalog\` after adding or changing a policy; CI fails the build"
  echo "if this file doesn't match what that command produces."
  echo

  for category_dir in supply-chain workload-hardening governance generate; do
    dir="$policies_dir/$category_dir"
    [ -d "$dir" ] || continue

    files=("$dir"/*.yaml)
    [ -e "${files[0]}" ] || continue

    heading="$(yq -r '.metadata.annotations."policies.kyverno.io/category" // "Uncategorized"' "${files[0]}")"
    echo "## $heading"
    echo

    for f in $(ls "$dir"/*.yaml | sort); do
      name="$(yq -r '.metadata.name' "$f")"
      title="$(yq -r '.metadata.annotations."policies.kyverno.io/title" // .metadata.name' "$f")"
      severity="$(yq -r '.metadata.annotations."policies.kyverno.io/severity" // "unspecified"' "$f")"
      subject="$(yq -r '.metadata.annotations."policies.kyverno.io/subject" // "unspecified"' "$f")"
      description="$(yq -r '.metadata.annotations."policies.kyverno.io/description" // "" ' "$f" | tr -s '\n ' ' ' | sed 's/^ *//;s/ *$//')"
      rationale="$(yq -r '.metadata.annotations."nearvic.io/rationale" // ""' "$f" | tr -s '\n ' ' ' | sed 's/^ *//;s/ *$//')"
      compliance="$(yq -r '.metadata.annotations."nearvic.io/compliance" // "none mapped"' "$f")"
      relpath="policies/${category_dir}/$(basename "$f")"
      testdir="policies/tests/${name}"

      echo "### $title"
      echo
      echo "- **Policy file:** [\`$relpath\`](../$relpath)"
      echo "- **Severity:** $severity"
      echo "- **Subject:** $subject"
      echo "- **Compliance mapping:** $compliance"
      if [ -d "$policies_dir/tests/$name" ]; then
        echo "- **Tests:** [\`$testdir\`](../$testdir)"
      else
        echo "- **Tests:** none found"
      fi
      echo
      echo "$description"
      echo
      echo "**Why this exists:** $rationale"
      echo
    done
  done
} > "$out"

echo "wrote $out"
