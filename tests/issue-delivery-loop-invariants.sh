#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=issue-delivery-loop-invariants
source tests/lib/assertions.sh

skill=issue-delivery-loop/SKILL.md
parent=start-build/reference/parent-orchestrator.md

for token in \
  'forge preflight' \
  'default-branch CI health' \
  'serial by default' \
  'dependency ordering' \
  'Decoupling Contract' \
  'coordinator checkout' \
  'must not copy auxiliary-index artifacts' \
  '≥20 files' \
  '≥1000 diff lines' \
  'Ten or more test files/shared harness changes' \
  'mr-builder-trivial' \
  'mr-builder-moderate' \
  'mr-builder-high-risk' \
  'mr-reviewer-final' \
  'parent-orchestrator.md' \
  'parent-owned Gate Receipt' \
  'runtime notices never become scope stop instructions' \
  'Event-driven waiting only' \
  'in parallel with CI' \
  'failed/canceled bound CI run blocks pass/finish' \
  'keep verdict, approval, and finish separate' \
  'Finish owner: parent' \
  'auto-merge queued' \
  'Provider merge-event evidence' \
  'post_merge_snapshot.kind=post-merge-snapshot' \
  'cleanup_pending' \
  '#380 coordinator-isolation' \
  'cleanup ordering' \
  'Project-profile hooks' \
  'provider-native post-read'; do
  assert_file_contains "$skill" "$token" "delivery-loop contract: $token"
done

assert_file_not_contains "$skill" 'skill://gitlab' "direct GitLab skill ownership"
assert_file_not_contains "$skill" 'glab ' "direct GitLab command ownership"

for token in \
  'mr-builder-trivial' \
  'mr-builder-moderate' \
  'mr-builder-high-risk' \
  'mr-reviewer-final' \
  'Gate owner' \
  'Finish owner' \
  'coordinator checkout'; do
  assert_file_contains "$parent" "$token" "parent pointer target: $token"
done

for token in \
  'session-owned worktree ledger' \
  'coordinator_path="$(cd "$coordinator_path" && pwd -P)"' \
  'child_worktree_path="$(cd "$child_worktree_path" && pwd -P)"' \
  'No repository-wide worktree discovery result' \
  '`--coordinator-path "$coordinator_path"`' \
  'every local-mutating finish call' \
  '`--worktree-path "$child_worktree_path"`' \
  'residual session-owned worktree'; do
  assert_file_contains "$parent" "$token" "coordinator cleanup safeguard: $token"
done

for token in \
  'session-owned worktree ledger' \
  'residual session-owned worktree'; do
  assert_file_contains "$skill" "$token" "delivery-loop cleanup pointer: $token"
done

printf '%s\n' "issue-delivery-loop-invariants: PASS"
