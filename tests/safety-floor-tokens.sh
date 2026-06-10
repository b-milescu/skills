#!/usr/bin/env bash
set -euo pipefail

# Safety-floor token coverage (issue #254).
#
# The "must not weaken" safety-floor litany, plus variant floor inventories,
# appears across 16 sites. This test pins EXACTLY the floor tokens present at
# HEAD per site so that dropping or weakening a floor sentence anywhere fails
# `npm run check`. Token spread is uneven by design: a uniform token loop is
# wrong (e.g. parent-orchestrator.md lacks `reviewed-SHA binding` and
# `verifier read-only`; issue-delivery-loop/SKILL.md carries a subset). The
# per-site matrix below was generated from HEAD; it is the deliverable.
#
# Zero doc wording changes accompany this test. If a future MR legitimately
# changes floor wording at a site, regenerate the matrix from the new HEAD in
# the same MR so the floor inventory and its pin cannot drift apart silently.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

failures=0

# Literal, newline-tolerant substring presence check. Floor tokens contain
# regex metacharacters (slashes, backticks, parentheses), so matching is fixed
# (`grep -F`); the `tr` fallback tolerates tokens wrapped across lines.
require_token() {
  local file="$1" token="$2"
  if [[ ! -f "$file" ]]; then
    echo "safety-floor-tokens: FAIL: $file does not exist (cannot pin floor token)" >&2
    failures=$((failures + 1))
    return
  fi
  if grep -Fq -- "$token" "$file"; then
    return
  fi
  if tr '\n' ' ' < "$file" | grep -Fq -- "$token"; then
    return
  fi
  echo "safety-floor-tokens: FAIL: $file missing floor token: $token" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# Canonical "must not weaken" floor litany tokens.
# ---------------------------------------------------------------------------
LITANY_REVIEWED_SHA="reviewed-SHA binding"
LITANY_EXACT_SHA_CI="exact-SHA CI"
LITANY_AUTHORITY_SOURCE="explicit authority source"
LITANY_INDEPENDENT_REVIEW="independent review"
LITANY_CHILD_BUILDER="child-builder"
LITANY_VERIFIER_RO="verifier read-only"
LITANY_MCP_FIRST="MCP-first transport correctness"
LITANY_HELP_FIRST="help-first \`glab\` fallback correctness"

# The full litany, shared by 14 of the 16 sites at HEAD.
FULL_LITANY=(
  "$LITANY_REVIEWED_SHA"
  "$LITANY_EXACT_SHA_CI"
  "$LITANY_AUTHORITY_SOURCE"
  "$LITANY_INDEPENDENT_REVIEW"
  "$LITANY_CHILD_BUILDER"
  "$LITANY_VERIFIER_RO"
  "$LITANY_MCP_FIRST"
  "$LITANY_HELP_FIRST"
)

# Sites carrying the full litany at HEAD (14 of 16).
FULL_LITANY_SITES=(
  "gitlab/SKILL.md"
  "setup-dev-skills/check-gate.md"
  "start-review/SKILL.md"
  "docs/agents/check-gate.md"
  "start-build/SKILL.md"
  "start-build/BUILD-FLOW.md"
  "start-build/templates/gitlab-delivery-schema.md"
  "start-build/reference/child-builder.md"
  "start-build/reference/context-and-planning.md"
  "start-review/REVIEW-FLOW.md"
  "docs/agents/dev-workflows.md"
  "setup-dev-skills/dev-workflows-gitlab.md"
  "docs/agents/triage-labels.md"
  "setup-dev-skills/triage-labels.md"
)

for site in "${FULL_LITANY_SITES[@]}"; do
  for token in "${FULL_LITANY[@]}"; do
    require_token "$site" "$token"
  done
done

# ---------------------------------------------------------------------------
# Uneven sites: pin EXACTLY the floor tokens present at HEAD.
# ---------------------------------------------------------------------------

# start-build/reference/parent-orchestrator.md — the parent flow phrases its
# floor list around its own role, so it lacks `reviewed-SHA binding` (it pins
# "reviewed SHAs ... stay bound") and `verifier read-only` (it pins
# "post-merge verifiers stay read-only"). Pin only what is present.
PARENT_ORCH="start-build/reference/parent-orchestrator.md"
require_token "$PARENT_ORCH" "$LITANY_EXACT_SHA_CI"
require_token "$PARENT_ORCH" "$LITANY_AUTHORITY_SOURCE"
require_token "$PARENT_ORCH" "$LITANY_INDEPENDENT_REVIEW"
require_token "$PARENT_ORCH" "$LITANY_CHILD_BUILDER"
require_token "$PARENT_ORCH" "$LITANY_MCP_FIRST"
require_token "$PARENT_ORCH" "$LITANY_HELP_FIRST"

# issue-delivery-loop/SKILL.md — pins a subset: it omits
# `explicit authority source`, `verifier read-only`, and
# `help-first \`glab\` fallback correctness` at HEAD.
DELIVERY_LOOP="issue-delivery-loop/SKILL.md"
require_token "$DELIVERY_LOOP" "$LITANY_REVIEWED_SHA"
require_token "$DELIVERY_LOOP" "$LITANY_EXACT_SHA_CI"
require_token "$DELIVERY_LOOP" "$LITANY_INDEPENDENT_REVIEW"
require_token "$DELIVERY_LOOP" "$LITANY_CHILD_BUILDER"
require_token "$DELIVERY_LOOP" "$LITANY_MCP_FIRST"

# ---------------------------------------------------------------------------
# Per-site deliberate extras (floors stronger than the shared litany).
# These are intentional per the consensus design; pin them so they cannot be
# silently dropped.
# ---------------------------------------------------------------------------

# gitlab/SKILL.md — transport, fallback-discipline, and GitLab record-naming
# floors that live only here.
require_token "gitlab/SKILL.md" "caller-identity/token-stability"
require_token "gitlab/SKILL.md" "context-firewall"
require_token "gitlab/SKILL.md" "content-byte safeguards"
require_token "gitlab/SKILL.md" "this fallback help-first rule"
require_token "gitlab/SKILL.md" "live \`glab --help\` verification"
require_token "gitlab/SKILL.md" "must not rename GitLab records in shared delivery blocks"

# start-build/reference/parent-orchestrator.md — credentials/read-only and the
# enumerated child-builder finish boundary.
require_token "$PARENT_ORCH" "credentials and product/runtime/operator external systems are not exposed"
require_token "$PARENT_ORCH" "post-merge verifiers stay read-only"
require_token "$PARENT_ORCH" "child builders do not spawn reviewers, approve, merge, queue auto-merge"

# ---------------------------------------------------------------------------
# Cross-check: effort-scaling §Hard floors. The Hard-floors litany phrases the
# same invariants differently; pin its stable tokens so the two floor
# inventories cannot drift apart silently.
# ---------------------------------------------------------------------------
EFFORT_SCALING="start-build/docs/effort-scaling.md"
require_token "$EFFORT_SCALING" "Hard floors (never scaled away)"
require_token "$EFFORT_SCALING" "mandatory independent review gate"
require_token "$EFFORT_SCALING" "SHA/CI/authority guards"
require_token "$EFFORT_SCALING" "builder/context-firewall finish boundaries"

if [[ "$failures" -ne 0 ]]; then
  echo "safety-floor-tokens: FAIL: $failures floor-token violation(s)" >&2
  exit 1
fi

echo "safety-floor-tokens: PASS"
