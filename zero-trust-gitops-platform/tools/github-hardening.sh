#!/usr/bin/env bash
# Phase 9 (BRIEF.md §10): GitHub repository hardening for the EXISTING
# beniaXcode/yahia-benabbou-portfolio repository — not a new repo (this
# project's top-level rule is to reuse that repo on this branch, never to
# create beniaxcode/zero-trust-gitops-platform as BRIEF.md's own text
# assumes before that constraint was given).
#
# This script was never run: no session working on this repository has had
# `gh`/GitHub API access broad enough to perform repository administration
# (branch rulesets, security-feature toggles, environments, Pages settings,
# releases, topics) — every available GitHub tool in that session was
# scoped to content/PR/issue operations, not repo settings. See
# docs/fidelity.md's Phase 9 entry for the full explanation. Run this by
# hand, from a machine with `gh auth login` completed against an account
# with admin rights on this repository, after reading every command below —
# per BRIEF.md's own instruction ("print each command before running it;
# ask for confirmation before anything destructive"), nothing here is
# wrapped in a blind loop.
set -euo pipefail

REPO="beniaXcode/yahia-benabbou-portfolio"

confirm() {
  echo
  echo "About to run:"
  echo "  $*"
  read -r -p "Proceed? [y/N] " reply
  case "$reply" in
    [yY]*) "$@" ;;
    *) echo "skipped" ;;
  esac
}

echo "==> checking gh auth and scopes"
gh auth status
echo "If a required scope is missing, run: gh auth refresh -s repo -s admin:repo_hook"

echo
echo "==> topics"
confirm gh repo edit "$REPO" \
  --add-topic gitops --add-topic devsecops --add-topic zero-trust \
  --add-topic supply-chain-security --add-topic kubernetes --add-topic argocd \
  --add-topic kyverno --add-topic sigstore --add-topic cosign --add-topic slsa \
  --add-topic oidc --add-topic aws --add-topic eks --add-topic terraform \
  --add-topic policy-as-code --add-topic platform-engineering

echo
echo "==> repository settings"
echo "NOTE: this repo hosts several unrelated portfolio case studies on other"
echo "branches. --enable-wiki/--enable-projects/etc. are repo-wide; confirm"
echo "before running anything here that would affect those, not just this branch."
confirm gh repo edit "$REPO" \
  --enable-wiki=false --enable-projects=false \
  --enable-issues=true --enable-discussions=true \
  --delete-branch-on-merge=true \
  --allow-squash-merge=true --allow-merge-commit=false --allow-rebase-merge=false

echo
echo "==> security features (each is a separate API call gh repo edit doesn't cover)"
confirm gh api -X PATCH "repos/${REPO}" \
  -f security_and_analysis'[secret_scanning][status]'=enabled \
  -f security_and_analysis'[secret_scanning_push_protection][status]'=enabled
confirm gh api -X PUT "repos/${REPO}/vulnerability-alerts"
confirm gh api -X PUT "repos/${REPO}/automated-security-fixes"
confirm gh api -X PUT "repos/${REPO}/private-vulnerability-reporting"
echo "CodeQL: .github/workflows/codeql.yml (Phase 4) is already the 'advanced setup'"
echo "path — no separate API toggle needed unless GitHub's default setup was ever"
echo "enabled first, which would conflict with it."
echo "Actions permissions (restrict to SHA-pinned actions) has no gh subcommand;"
echo "set it at: https://github.com/${REPO}/settings/actions"

echo
echo "==> branch ruleset on main"
echo "IMPORTANT: required status checks can only name checks GitHub has already"
echo "seen run at least once against this repo. Push this branch (or open a PR"
echo "from it) first, let ci.yml/iac-scan.yml/policy-test.yml/e2e-kind.yml/"
echo "verify-no-secrets.yml run for real, THEN fill in the exact check names"
echo "below from what actually appears in the PR's checks list (job names as of"
echo "this commit: lint-and-test-app, gitleaks, shift-left-admission-preview,"
echo "no-placeholders (ci.yml); tflint, checkov, terraform-validate-and-test,"
echo "conftest-policy-fixtures (iac-scan.yml); kyverno-test, chainsaw"
echo "(policy-test.yml); verify-no-secrets; e2e (e2e-kind.yml) — confirm the"
echo "exact rendered names, don't assume job id == check name)."
cat <<'JSON' > /tmp/main-ruleset.json
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true
    }},
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "REPLACE-WITH-REAL-CHECK-NAME-ci" },
          { "context": "REPLACE-WITH-REAL-CHECK-NAME-policy-test" },
          { "context": "REPLACE-WITH-REAL-CHECK-NAME-iac-scan" },
          { "context": "REPLACE-WITH-REAL-CHECK-NAME-e2e-kind" },
          { "context": "REPLACE-WITH-REAL-CHECK-NAME-verify-no-secrets" }
        ]
    }},
    { "type": "required_signatures" },
    { "type": "required_linear_history" },
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ],
  "bypass_actors": []
}
JSON
echo "Edit /tmp/main-ruleset.json's REPLACE-WITH-REAL-CHECK-NAME-* values first."
confirm gh api -X POST "repos/${REPO}/rulesets" --input /tmp/main-ruleset.json

echo
echo "==> environments (dev: no gate; staging/prod: required reviewer)"
echo "Environment secrets must never be created here — only variables (an ARN"
echo "is safe to publish; see docs/identity-model.md's 'why this is safe to"
echo "publish' note). Replace <ACCOUNT_ID> with a real AWS account ID before running."
for env in dev staging prod; do
  confirm gh api -X PUT "repos/${REPO}/environments/${env}"
  confirm gh api -X PUT "repos/${REPO}/environments/${env}/variables/AWS_REGION" -f value=us-east-1
  confirm gh api -X PUT "repos/${REPO}/environments/${env}/variables/ECR_REPOSITORY" -f value=zero-trust-gitops-platform
  confirm gh api -X PUT "repos/${REPO}/environments/${env}/variables/AWS_ROLE_ARN" \
    -f value="arn:aws:iam::<ACCOUNT_ID>:role/zero-trust-gitops-platform-build"
done
echo "staging/prod required-reviewer and prod's 5-minute wait timer need the"
echo "environment protection-rules API — set at:"
echo "https://github.com/${REPO}/settings/environments"

echo
echo "==> Pages"
confirm gh api -X POST "repos/${REPO}/pages" -f "build_type=workflow"
echo "Then add a docs-deploy job to a workflow using actions/deploy-pages once"
echo "the above succeeds — Pages must exist before that action has anywhere to publish to."

echo
echo "==> release v0.1.0"
echo "Only after a real signed image + digest + Rekor log index exist (i.e."
echo "after build-sign-attest.yml has actually run once on this branch/main)."
echo "gh release create v0.1.0 --title 'v0.1.0' --notes-file <(cat <<'EOF'"
echo "  ## What this is"
echo "  ..."
echo "  ## Verify the signed image"
echo "  cosign verify ghcr.io/beniaxcode/yahia-benabbou-portfolio/demo-api@<digest> ..."
echo "  Rekor log index: <index>, https://search.sigstore.dev"
echo "EOF"
echo ")"

echo
echo "==> verify"
confirm gh secret list --repo "$REPO"
echo "Expect: empty. Then run OpenSSF Scorecard: https://github.com/marketplace/actions/ossf-scorecard-action"
echo "(already wired as .github/workflows/scorecard.yml — check its latest run's score)."
