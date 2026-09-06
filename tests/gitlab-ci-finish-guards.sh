#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'gitlab-ci-finish-guards: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains retired $3"; }

CARD="gitlab/reference/ci-finish-guards.md"
SKILL="gitlab/SKILL.md"
SCHEMA="$REPO_ROOT/gitlab/reference/finish-result-schema.json"

require "$CARD" 'GitLab Mutation Guard' 'shared guard pointer'
require "$CARD" 'list_pipelines\(sha=reviewed_sha\)|get_pipeline' 'exact-SHA advisory observation'
require "$CARD" 'never determines review or finish eligibility' 'advisory watcher policy'
require "$CARD" 'optional and nullable advisory evidence' 'nullable CI output'
require "$CARD" 'exact-candidate local Gate Receipt' 'singular quality gate'
require "$CARD" 'at most one action|exactly one mutation' 'one finish mutation'
require "$CARD" 'provider-native readback' 'native readback'
require "$CARD" 'provider result and never bypass' 'native refusal reporting'
require "$CARD" 'closure_pending' 'closure pending token'
retired='no_ci_''expected|ci_not_''green|ci_''guard|stale_''ci|red_''ci|missing_''ci'
reject "$CARD" "$retired" 'CI exception/guard/blocker vocabulary'

require "$SKILL" 'CI status is advisory' 'advisory action policy'
reject "$SKILL" "$retired|stale/red/missing CI" 'retired finish blocker vocabulary'

SCHEMA_PATH="$SCHEMA" node -e '
  const schema = require(process.env.SCHEMA_PATH);
  const ci = schema.properties.ci;
  if (!ci || !ci.type.includes("object") || !ci.type.includes("null")) process.exit(1);
  const retiredGuard = "ci_" + "guard";
  const retiredBlocker = "ci_not_" + "green";
  if (schema.required.includes("ci") || schema.required.includes(retiredGuard)) process.exit(2);
  if (retiredGuard in schema.properties || schema.properties.blocker.enum.includes(retiredBlocker)) process.exit(3);
' || fail "finish-result schema CI shape is not optional nullable advisory evidence"

printf 'gitlab-ci-finish-guards: PASS\n'