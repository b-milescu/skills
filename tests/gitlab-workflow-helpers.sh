#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="gitlab-workflow-helpers"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-workflow-helpers.XXXXXX")"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# shellcheck source=tests/lib/gitlab-fixtures.sh
source "$REPO_ROOT/tests/lib/gitlab-fixtures.sh"


test_native_helper_path_and_comparison_guidance() {
  local skill
  skill="$REPO_ROOT/gitlab/SKILL.md"

  assert_file_contains "$skill" "non-shell binaries must use a namespace that binary can resolve: prefer repo-relative paths, or drive-letter form" "native helper path namespace"
  assert_file_contains "$skill" "caller-local helper" "caller-local helper fallback"
  assert_file_contains "$skill" "comparison tool's exit status" "comparison exit status"
  assert_file_contains "$skill" "must not suppress stderr" "comparison stderr visibility"
  assert_file_contains "$skill" 'Treat any `cd` failure as fatal' "fatal directory change"
}

test_merge_watch_reports_merge_completion_terminals() {
  local dir good_sha old_sha merge_sha squash_sha
  good_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  old_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  merge_sha=cccccccccccccccccccccccccccccccccccccccc
  squash_sha=dddddddddddddddddddddddddddddddddddddddd

  # Merged at the reviewed SHA -> result=merged + merge_commit, exit 0.
  dir="$(make_wrapper_fixture_dir merge-watch-merged-human)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$good_sha" success "$good_sha" "$merge_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "MERGE_WATCH result=merged"
  assert_contains "$CAPTURE_OUTPUT" "merge_commit=$merge_sha"

  # YAML format surfaces the merged result and merge-commit SHA.
  dir="$(make_wrapper_fixture_dir merge-watch-merged-yaml)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$good_sha" success "$good_sha" "$merge_sha"
  run_merge_watch_fixture "$dir" "$good_sha" 0 yaml
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "result: merged"
  assert_contains "$CAPTURE_OUTPUT" "merge_commit: \"$merge_sha\""

  # Squash merge: no merge_commit_sha, squash_commit_sha is used.
  dir="$(make_wrapper_fixture_dir merge-watch-merged-squash)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$good_sha" success "$good_sha" "" "$squash_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "result=merged"
  assert_contains "$CAPTURE_OUTPUT" "merge_commit=$squash_sha"

  # Merged with no readable merge/squash SHA still terminal pass, exit 0.
  dir="$(make_wrapper_fixture_dir merge-watch-merged-no-sha)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$good_sha" success "$good_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "result=merged"
  assert_contains "$CAPTURE_OUTPUT" "merge_commit=none"

  # Reviewed-SHA pipeline failed -> blocked (auto-merge will not complete), exit 1.
  dir="$(make_wrapper_fixture_dir merge-watch-ci-failed)"
  write_merge_watch_mr_json "$dir/mr.json" opened "$good_sha" failed "$good_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 1
  assert_contains "$CAPTURE_OUTPUT" "result=ci_failed"
  assert_not_contains "$CAPTURE_OUTPUT" "result=merged"

  # Reviewed-SHA pipeline canceled also blocks, exit 1.
  dir="$(make_wrapper_fixture_dir merge-watch-ci-canceled)"
  write_merge_watch_mr_json "$dir/mr.json" opened "$good_sha" canceled "$good_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 1
  assert_contains "$CAPTURE_OUTPUT" "result=ci_failed"

  # Head drifted off the reviewed SHA -> head_changed, exit 2.
  dir="$(make_wrapper_fixture_dir merge-watch-head-changed)"
  write_merge_watch_mr_json "$dir/mr.json" opened "$old_sha" success "$old_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "result=head_changed"

  # Merged but observed head != reviewed SHA must fail closed as head_changed
  # (exit 2), never report a clean merge of an unreviewed commit.
  dir="$(make_wrapper_fixture_dir merge-watch-merged-stale-head)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$old_sha" success "$old_sha" "$merge_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "result=head_changed"
  assert_not_contains "$CAPTURE_OUTPUT" "result=merged"

  # Still opened with a pending pipeline at the reviewed SHA -> timeout, exit 4.
  dir="$(make_wrapper_fixture_dir merge-watch-timeout)"
  write_merge_watch_mr_json "$dir/mr.json" opened "$good_sha" running "$good_sha"
  run_merge_watch_fixture "$dir" "$good_sha" 0
  assert_status 4
  assert_contains "$CAPTURE_OUTPUT" "result=timeout"

  # Closed without merging -> unknown_mr_state, exit 5, never success.
  dir="$(make_wrapper_fixture_dir merge-watch-closed)"
  write_merge_watch_mr_json "$dir/mr.json" closed "$good_sha" success "$good_sha"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=unknown_mr_state"
  assert_not_contains "$CAPTURE_OUTPUT" "result=merged"
}

test_merge_watch_fails_closed_on_control_char_body() {
  local dir good_sha merge_sha cc_desc
  good_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  merge_sha=cccccccccccccccccccccccccccccccccccccccc
  cc_desc=$'Review Packet\001body'

  # The retro defect: a hand-rolled `glab ... -F json | jq` background waiter
  # parse-errors on every poll when the MR description carries raw control
  # characters and silently never observes the merge. Over safe_mr_json the
  # watcher fails closed with a clear terminal instead of looping or claiming
  # success, even though the MR is merged.
  dir="$(make_wrapper_fixture_dir merge-watch-control-char)"
  write_merge_watch_mr_json "$dir/mr.json" merged "$good_sha" success "$good_sha" "$merge_sha" "" "$cc_desc"
  run_merge_watch_fixture "$dir" "$good_sha"
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "result=blocked"
  assert_contains "$CAPTURE_OUTPUT" "reason=invalid_control_character"
  assert_not_contains "$CAPTURE_OUTPUT" "result=merged"
}

test_merge_watch_reads_via_safe_mr_json_not_jq() {
  local helper
  helper="$REPO_ROOT/gitlab/scripts/gitlab-merge-watch.sh"
  assert_path_readable "$helper" "merge-watch helper"
  # Acceptance invariant: read state through safe_mr_json, never raw jq on the
  # full MR body. Comments may reference the avoided `glab ... | jq` pattern, so
  # only flag jq used in executable (non-comment) lines.
  assert_file_contains "$helper" "safe_mr_json" "safe_mr_json read path"
  if awk '!/^[[:space:]]*#/ && /jq/ { found = 1 } END { exit found ? 0 : 1 }' "$helper"; then
    fail "gitlab-merge-watch.sh must not parse the MR body with jq in executable code"
  fi
}

test_finish_builder_handoff_never_approves_or_merges() {
  local dir
  dir="$(make_fixture_dir finish-builder)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role builder \
    --source-branch build/61 \
    --default-branch main

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=handoff"
  assert_contains "$CAPTURE_OUTPUT" "builder_no_approve_or_merge"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
  assert_log_not_contains "$dir/glab.log" "approve"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_finish_reports_issue_state_on_handoff_when_issue_iid_is_supplied() {
  local dir
  dir="$(make_fixture_dir finish-issue-handoff)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  write_issue_json "$dir/issue.json" opened

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority approval-only \
    --caller-role reviewer \
    --source-branch build/61 \
    --default-branch main \
    --issue-iid 88

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=handoff"
  assert_contains "$CAPTURE_OUTPUT" "issue_state=opened"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
  assert_log_contains "$dir/glab.log" "glab issue view 88 -F json"
  assert_log_not_contains "$dir/glab.log" "approve"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_finish_yaml_format_reports_structured_handoff() {
  local dir
  dir="$(make_fixture_dir finish-yaml-handoff)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role builder \
    --source-branch build/61 \
    --default-branch main \
    --format yaml

  assert_status 0
  assert_yaml_field result handoff
  assert_yaml_field action handoff
  assert_yaml_field transport glab-fallback
  assert_yaml_field mr 59
  assert_yaml_field reviewed_sha abc123
  assert_yaml_field ci_guard green
  assert_yaml_field pipeline_status success
  assert_yaml_field pipeline_sha abc123
  assert_yaml_field issue_state not_checked
  assert_yaml_field branch not_requested
  assert_log_not_contains "$dir/glab.log" "approve"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_finish_authorized_paths_are_sha_bound() {
  local dir
  dir="$(make_fixture_dir finish-reviewer-merge)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role reviewer \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --approve-as-reviewer

  assert_status 0
  assert_log_contains "$dir/glab.log" "glab mr approve 59 --sha abc123"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --yes --sha abc123 --auto-merge=false"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"

  dir="$(make_fixture_dir finish-auto-merge)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator"

  assert_status 0
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --auto-merge --yes --sha abc123"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
}

test_finish_reports_issue_and_deletes_source_branches_after_direct_merge() {
  local coordinator dir
  dir="$(make_fixture_dir finish-merge-cleanup)"
  mkdir -p "$dir/coordinator"
  coordinator="$(cd "$dir/coordinator" && pwd -P)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  write_issue_json "$dir/issue.json" closed

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --issue-iid 88 \
    --delete-local-source-branch \
    --delete-remote-source-branch

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
  assert_contains "$CAPTURE_OUTPUT" "issue_state=closed"
  assert_contains "$CAPTURE_OUTPUT" "branch=local_deleted,remote_deleted"
  assert_log_contains "$dir/glab.log" "glab issue view 88 -F json"
  assert_log_contains "$dir/git.log" "git -C $coordinator branch -d build/61"
  assert_log_contains "$dir/git.log" "git -C $coordinator push origin --delete build/61"
}

test_finish_rejects_unsafe_cleanup_paths_before_merge() {
  local coordinator dir
  dir="$(make_fixture_dir finish-missing-coordinator)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=coordinator_path_missing"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-relative-coordinator)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path relative-coordinator
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=coordinator_path_not_absolute"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-parent-owner-missing-coordinator)"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --finish-owner parent \
    --source-branch build/61 \
    --default-branch main
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=coordinator_path_missing"
  assert_log_not_contains "$dir/glab.log" "merge"



  dir="$(make_fixture_dir finish-relative-worktree)"
  coordinator="$dir/coordinator"
  mkdir -p "$coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --worktree-path relative-child
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=worktree_path_not_absolute"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-missing-worktree)"
  coordinator="$dir/coordinator"
  mkdir -p "$coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --worktree-path "$dir/missing-child"
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=worktree_path_missing"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-worktree-collision)"
  coordinator="$dir/coordinator"
  mkdir -p "$coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --worktree-path "$coordinator"
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=worktree_path_collision"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_finish_blocks_local_cleanup_until_default_is_verified_safe() {
  local child coordinator dir

  dir="$(make_fixture_dir finish-cleanup-dirty-default)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_GIT_STATUS=' M coordinator-file' run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --worktree-path "$dir/child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:dirty_checkout"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:dirty_checkout"
  assert_log_not_contains "$dir/git.log" "git worktree remove $dir/child"
  assert_log_not_contains "$dir/git.log" "git branch -d build/61"

  dir="$(make_fixture_dir finish-cleanup-merge-sha)"
  mkdir -p "$dir/coordinator" "$dir/child"
  child="$(cd "$dir/child" && pwd -P)"
  coordinator="$(cd "$dir/coordinator" && pwd -P)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123 merge999
  write_branch_json "$dir/branch.json" success abc123
  FAKE_MERGE_BASE_ACCEPTS=merge999 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --worktree-path "$child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=removed"
  assert_contains "$CAPTURE_OUTPUT" "coordinator=verified_default:main"
  assert_log_contains "$dir/git.log" "git -C $coordinator merge-base --is-ancestor abc123 main"
  assert_log_contains "$dir/git.log" "git -C $coordinator merge-base --is-ancestor merge999 main"
  assert_log_contains "$dir/git.log" "git -C $coordinator worktree remove $child"
  assert_log_contains "$dir/git.log" "git -C $coordinator branch -d build/61"
  dir="$(make_fixture_dir finish-cleanup-containment-failure)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_MERGE_BASE_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --worktree-path "$dir/child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:containment_unverified"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:containment_unverified"
  assert_contains "$CAPTURE_OUTPUT" "coordinator=verified_default:main"
  assert_log_not_contains "$dir/git.log" "worktree remove"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"
}


test_finish_retains_worktree_not_bound_to_recorded_source_branch() {
  local dir

  dir="$(make_fixture_dir finish-worktree-branch-mismatch)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_WORKTREE_BRANCH=other-branch run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --worktree-path "$dir/child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:source_branch_mismatch"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:worktree_retained"
  assert_log_not_contains "$dir/git.log" "worktree remove"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"
}

test_finish_retains_unregistered_and_remove_failed_worktrees() {
  local dir

  dir="$(make_fixture_dir finish-worktree-unregistered)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_COORDINATOR_COMMON_DIR=/repo/.git FAKE_WORKTREE_COMMON_DIR=/other/.git \
    run_finish_fixture "$dir" \
      --mr-iid 59 \
      --reviewed-sha abc123 \
      --merge-authority "reviewer may merge" \
      --caller-role authorized-parent \
      --source-branch build/61 \
      --default-branch main \
      --coordinator-path "$dir/coordinator" \
      --worktree-path "$dir/child" \
      --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:unregistered_worktree"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:worktree_retained"
  assert_log_not_contains "$dir/git.log" "worktree remove"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"

  dir="$(make_fixture_dir finish-worktree-remove-failed)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_WORKTREE_REMOVE_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --worktree-path "$dir/child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:remove_failed"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:worktree_retained"
  assert_log_contains "$dir/git.log" "worktree remove"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"
}

test_finish_cleanup_flags_do_not_delete_branches_on_handoff_or_failures() {
  local coordinator dir

  dir="$(make_fixture_dir finish-cleanup-handoff)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role builder \
    --source-branch build/61 \
    --default-branch main \
    --delete-local-source-branch \
    --delete-remote-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=handoff"
  assert_log_not_contains "$dir/git.log" "git branch -d build/61"
  assert_log_not_contains "$dir/git.log" "git push origin --delete build/61"

  dir="$(make_fixture_dir finish-cleanup-failure)"
  write_mr_json "$dir/mr.json" opened abc123 success old999
  write_branch_json "$dir/branch.json" success old999
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --delete-local-source-branch \
    --delete-remote-source-branch
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "reason=stale_ci"
  assert_log_not_contains "$dir/git.log" "git branch -d build/61"
  assert_log_not_contains "$dir/git.log" "git push origin --delete build/61"

  dir="$(make_fixture_dir finish-cleanup-unmerged)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123
  coordinator="$(cd "$dir/coordinator" && pwd -P)"
  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$coordinator" \
    --worktree-path "$dir/child" \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:merge_not_verified"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:merge_not_verified"
  assert_log_not_contains "$dir/git.log" "worktree remove"
  assert_contains "$CAPTURE_OUTPUT" "coordinator=verified_default:main"
  assert_log_contains "$dir/git.log" "git -C $coordinator checkout main"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"
}

test_finish_remote_cleanup_requires_verified_default_containment() {
  local dir

  dir="$(make_fixture_dir finish-remote-containment-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_MERGE_BASE_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --delete-remote-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:containment_unverified"
  assert_log_contains "$dir/git.log" "merge-base --is-ancestor abc123 main"
  assert_log_not_contains "$dir/git.log" "push origin --delete build/61"

  dir="$(make_fixture_dir finish-remote-fetch-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_GIT_FETCH_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --delete-remote-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:fetch_failed"
  assert_log_not_contains "$dir/git.log" "push origin --delete build/61"

  dir="$(make_fixture_dir finish-remote-current-branch-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_CURRENT_BRANCH_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --delete-remote-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:current_branch_unreadable"
  assert_log_not_contains "$dir/git.log" "push origin --delete build/61"
}


test_finish_reports_post_mutation_git_failures() {
  local dir

  dir="$(make_fixture_dir finish-queue-fetch-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123
  FAKE_GIT_FETCH_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "coordinator=cleanup_pending:fetch_failed"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --auto-merge --yes --sha abc123"

  dir="$(make_fixture_dir finish-queue-current-branch-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123
  FAKE_CURRENT_BRANCH_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "coordinator=cleanup_pending:current_branch_unreadable"

  dir="$(make_fixture_dir finish-remote-delete-failed)"
  mkdir -p "$dir/coordinator"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_GIT_PUSH_STATUS=1 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --coordinator-path "$dir/coordinator" \
    --delete-remote-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:remote_delete_failed"
  assert_log_not_contains "$dir/git.log" "branch -d build/61"
}

test_finish_blocks_unsafe_states_before_mutation() {
  local dir

  dir="$(make_fixture_dir finish-head-change)"
  write_mr_json "$dir/mr.json" opened def456 success def456
  write_branch_json "$dir/branch.json" success def456
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=head_changed"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-stale-ci)"
  write_mr_json "$dir/mr.json" opened abc123 success old999
  write_branch_json "$dir/branch.json" success old999
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "reason=stale_ci"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-red-ci)"
  write_mr_json "$dir/mr.json" opened abc123 failed abc123
  write_branch_json "$dir/branch.json" failed abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "reason=ci_not_green"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-missing-ci)"
  printf '%s\n' '{"iid":59,"state":"opened","sha":"abc123","pipeline":null}' > "$dir/mr.json"
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "reason=missing_ci"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-missing-authority)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 4
  assert_contains "$CAPTURE_OUTPUT" "reason=missing_merge_authority"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-unknown-authority)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "maintainer merges" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 4
  assert_contains "$CAPTURE_OUTPUT" "reason=unknown_merge_authority"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-unknown-state)"
  write_mr_json "$dir/mr.json" locked abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=unknown_mr_state"
  assert_log_not_contains "$dir/glab.log" "merge"

  dir="$(make_fixture_dir finish-dirty-worktree)"
  mkdir -p "$dir/coordinator" "$dir/child"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_WORKTREE_STATUS=' M uncommitted-file' run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main --coordinator-path "$dir/coordinator" --worktree-path "$dir/child" --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "worktree=cleanup_pending:dirty_worktree"
  assert_contains "$CAPTURE_OUTPUT" "branch=cleanup_pending:worktree_retained"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --yes --sha abc123 --auto-merge=false"
  assert_log_not_contains "$dir/git.log" "worktree remove"
}

test_wrappers_create_issue_and_mr_notes_without_body_leak() {
  local dir message_file secret
  secret='secret-token-line'

  dir="$(make_wrapper_fixture_dir wrapper-issue-note)"
  message_file="$dir/message.md"
  printf '%s\nsecond line\n' "$secret" > "$message_file"
  FAKE_EXPECT_MESSAGE="$(cat "$message_file")" run_wrapper_fixture "$dir" \
    issue_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --message-file "$message_file"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "ISSUE_NOTE_CREATE result=created"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "issue note output leaked message body"
  assert_log_contains "$dir/glab.log" "glab issue note 173 -R git@gitlab.example.com:agents/skills.git --message <message-redacted>"
  assert_log_not_contains "$dir/glab.log" "$secret"
  assert_log_not_contains "$dir/glab.log" "mr note create"

  dir="$(make_wrapper_fixture_dir wrapper-mr-note)"
  message_file="$dir/message.md"
  printf '%s\nsecond line\n' "$secret" > "$message_file"
  FAKE_EXPECT_MESSAGE="$(cat "$message_file")" run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --message-file "$message_file"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "MR_NOTE_CREATE result=created"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR note output leaked message body"
  assert_log_contains "$dir/glab.log" "glab mr note create 59 -R git@gitlab.example.com:agents/skills.git --message <message-redacted> --resolvable=false"
  assert_log_not_contains "$dir/glab.log" "$secret"
  assert_log_not_contains "$dir/glab.log" "issue note"
}

test_wrappers_create_and_update_mr_descriptions_with_control_validation() {
  local dir description_file secret malformed_file
  secret='secret-token-line'

  dir="$(make_wrapper_fixture_dir wrapper-mr-create-description)"
  description_file="$dir/review-packet.md"
  printf '# Review Packet\n\n%s\n' "$secret" > "$description_file"
  FAKE_EXPECT_DESCRIPTION="$(cat "$description_file")" run_wrapper_fixture "$dir" \
    draft_mr_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --target-branch main \
    --source-branch issue-183 \
    --title "Draft title" \
    --description-file "$description_file"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "DRAFT_MR_CREATE result=created"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR create output leaked description body"
  assert_log_contains "$dir/glab.log" "glab mr create -R git@gitlab.example.com:agents/skills.git --draft --push --target-branch main --source-branch issue-183 --title Draft title --description <description-redacted> --yes"
  assert_log_not_contains "$dir/glab.log" "$secret"

  dir="$(make_wrapper_fixture_dir wrapper-mr-description-update)"
  description_file="$dir/review-packet.md"
  printf '# Reviewer Lift\n\n%s\n' "$secret" > "$description_file"
  FAKE_EXPECT_DESCRIPTION="$(cat "$description_file")" run_wrapper_fixture "$dir" \
    mr_description_update \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --description-file "$description_file"
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "MR_DESCRIPTION_UPDATE result=updated"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR update output leaked description body"
  assert_log_contains "$dir/glab.log" "glab mr update 59 -R git@gitlab.example.com:agents/skills.git --description <description-redacted>"
  assert_log_not_contains "$dir/glab.log" "$secret"

  dir="$(make_wrapper_fixture_dir wrapper-mr-create-nul)"
  malformed_file="$dir/malformed-review-packet.md"
  printf '# Review Packet\nsafe line\n\000%s\n' "$secret" > "$malformed_file"
  run_wrapper_fixture "$dir" \
    draft_mr_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --target-branch main \
    --source-branch issue-183 \
    --title "Draft title" \
    --description-file "$malformed_file"
  assert_validation_failure_without_glab_call "$dir" 65 "invalid_control_character:description_file"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR create control diagnostic leaked description body"
  [[ "$CAPTURE_OUTPUT" != *"Review Packet"* ]] || fail "MR create control diagnostic printed malformed packet"

  dir="$(make_wrapper_fixture_dir wrapper-mr-update-control)"
  malformed_file="$dir/malformed-review-packet.md"
  printf '# Reviewer Lift\nsafe line\n\001%s\n' "$secret" > "$malformed_file"
  run_wrapper_fixture "$dir" \
    mr_description_update \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --description-file "$malformed_file"
  assert_validation_failure_without_glab_call "$dir" 65 "invalid_control_character:description_file"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR update control diagnostic leaked description body"
  [[ "$CAPTURE_OUTPUT" != *"Reviewer Lift"* ]] || fail "MR update control diagnostic printed malformed packet"
}

test_wrappers_delegate_file_backed_validation_to_shared_content_guard() {
  local dir guard guard_log description_file message_file malformed_file secret
  secret='secret-token-line'

  dir="$(make_wrapper_fixture_dir wrapper-shared-content-guard)"
  guard="$dir/gitlab-content-guard.sh"
  guard_log="$dir/content-guard.log"
  cat > "$guard" <<'FAKE_GUARD'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_CONTENT_GUARD_LOG"
file=""
role=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) file="${2:-}"; shift 2 ;;
    --role) role="${2:-}"; shift 2 ;;
    *) echo "GITLAB_CONTENT_GUARD result=blocked reason=unknown_arg:$1" >&2; exit 64 ;;
  esac
done
[[ -n "$file" ]] || { echo "GITLAB_CONTENT_GUARD result=blocked reason=missing_file" >&2; exit 64; }
[[ -n "$role" ]] || { echo "GITLAB_CONTENT_GUARD result=blocked reason=missing_role" >&2; exit 64; }
case "$file" in
  *blocked*) echo "GITLAB_CONTENT_GUARD result=blocked reason=invalid_control_character:${role}:byte_7" >&2; exit 65 ;;
esac
FAKE_GUARD
  chmod +x "$guard"

  description_file="$dir/review-packet.md"
  printf '# Reviewer Lift\n\n%s\n' "$secret" > "$description_file"
  FAKE_EXPECT_DESCRIPTION="$(cat "$description_file")" GITLAB_CONTENT_GUARD="$guard" FAKE_CONTENT_GUARD_LOG="$guard_log" run_wrapper_fixture "$dir" \
    mr_description_update \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --description-file "$description_file"
  assert_status 0
  assert_log_contains "$guard_log" "--file $description_file --role description_file"

  message_file="$dir/message.md"
  printf '# Revision Packet\n\n%s\n' "$secret" > "$message_file"
  FAKE_EXPECT_MESSAGE="$(cat "$message_file")" GITLAB_CONTENT_GUARD="$guard" FAKE_CONTENT_GUARD_LOG="$guard_log" run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --message-file "$message_file"
  assert_status 0
  assert_log_contains "$guard_log" "--file $message_file --role message_file"

  : > "$dir/glab.log"
  malformed_file="$dir/blocked-review-packet.md"
  printf '# Reviewer Lift\n\n%s\n' "$secret" > "$malformed_file"
  GITLAB_CONTENT_GUARD="$guard" FAKE_CONTENT_GUARD_LOG="$guard_log" run_wrapper_fixture "$dir" \
    mr_description_update \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --description-file "$malformed_file"
  assert_validation_failure_without_glab_call "$dir" 65 "invalid_control_character:description_file:byte_7"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "delegated content-guard diagnostic leaked description body"
  [[ "$CAPTURE_OUTPUT" != *"Reviewer Lift"* ]] || fail "delegated content-guard diagnostic printed malformed packet"
}


test_wrappers_fail_closed_for_note_validation_without_glab_calls() {
  local dir message_file unreadable_file empty_file secret
  secret='secret-token-line'

  dir="$(make_wrapper_fixture_dir wrapper-issue-note-missing-target)"
  message_file="$dir/message.md"
  printf 'issue note body\n' > "$message_file"
  run_wrapper_fixture "$dir" \
    issue_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --message-file "$message_file"
  assert_validation_failure_without_glab_call "$dir" 64 missing_issue_iid

  dir="$(make_wrapper_fixture_dir wrapper-issue-note-missing-message-file)"
  run_wrapper_fixture "$dir" \
    issue_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173
  assert_validation_failure_without_glab_call "$dir" 64 missing_message_file

  dir="$(make_wrapper_fixture_dir wrapper-issue-note-unreadable-message-file)"
  unreadable_file="$dir/unreadable-message-dir"
  mkdir "$unreadable_file"
  run_wrapper_fixture "$dir" \
    issue_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --message-file "$unreadable_file"
  assert_validation_failure_without_glab_call "$dir" 66 unreadable_message_file

  dir="$(make_wrapper_fixture_dir wrapper-issue-note-empty-message-file)"
  empty_file="$dir/empty.md"
  : > "$empty_file"
  run_wrapper_fixture "$dir" \
    issue_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --message-file "$empty_file"
  assert_validation_failure_without_glab_call "$dir" 64 empty_message_file

  dir="$(make_wrapper_fixture_dir wrapper-mr-note-missing-target)"
  message_file="$dir/message.md"
  printf 'MR note body\n' > "$message_file"
  run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --message-file "$message_file"
  assert_validation_failure_without_glab_call "$dir" 64 missing_mr_iid

  dir="$(make_wrapper_fixture_dir wrapper-mr-note-missing-message-file)"
  run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59
  assert_validation_failure_without_glab_call "$dir" 64 missing_message_file

  dir="$(make_wrapper_fixture_dir wrapper-mr-note-unreadable-message-file)"
  unreadable_file="$dir/unreadable-message-dir"
  mkdir "$unreadable_file"
  run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --message-file "$unreadable_file"
  assert_validation_failure_without_glab_call "$dir" 66 unreadable_message_file

  dir="$(make_wrapper_fixture_dir wrapper-mr-note-empty-message-file)"
  empty_file="$dir/empty.md"
  : > "$empty_file"
  run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --message-file "$empty_file"
  assert_validation_failure_without_glab_call "$dir" 64 empty_message_file

  dir="$(make_wrapper_fixture_dir wrapper-mr-note-control-character)"
  message_file="$dir/message.md"
  printf '# Revision Packet\n\001%s\n' "$secret" > "$message_file"
  run_wrapper_fixture "$dir" \
    mr_note_create \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --message-file "$message_file"
  assert_validation_failure_without_glab_call "$dir" 65 "invalid_control_character:message_file"
  [[ "$CAPTURE_OUTPUT" != *"$secret"* ]] || fail "MR note control diagnostic leaked message body"
  [[ "$CAPTURE_OUTPUT" != *"Revision Packet"* ]] || fail "MR note control diagnostic printed malformed packet"
}

test_label_reconcile_adds_and_removes_without_replace_assumption() {
  local dir
  dir="$(make_wrapper_fixture_dir wrapper-label-reconcile)"
  printf '%s\n' '{"iid":173,"labels":["ready-for-agent","refactor"]}' > "$dir/issue.json"

  run_wrapper_fixture "$dir" \
    label_reconcile \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --add-labels docs \
    --remove-labels refactor \
    --state-labels ready,ready-for-agent \
    --category-labels docs,refactor

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "LABEL_RECONCILE result=updated"
  assert_contains "$CAPTURE_OUTPUT" "add=docs"
  assert_contains "$CAPTURE_OUTPUT" "remove=refactor"
  assert_log_contains "$dir/glab.log" "glab issue view 173 -R git@gitlab.example.com:agents/skills.git -F json"
  assert_log_contains "$dir/glab.log" "glab issue update 173 -R git@gitlab.example.com:agents/skills.git --label docs --unlabel refactor"

  dir="$(make_wrapper_fixture_dir wrapper-label-category-conflict)"
  printf '%s\n' '{"iid":173,"labels":["ready-for-agent","refactor"]}' > "$dir/issue.json"
  run_wrapper_fixture "$dir" \
    label_reconcile \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --add-labels docs \
    --state-labels ready,ready-for-agent \
    --category-labels docs,refactor
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=category_label_conflict"
  assert_log_not_contains "$dir/glab.log" "issue update"

  dir="$(make_wrapper_fixture_dir wrapper-label-state-conflict)"
  printf '%s\n' '{"iid":173,"labels":["ready-for-agent","refactor"]}' > "$dir/issue.json"
  run_wrapper_fixture "$dir" \
    label_reconcile \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --add-labels ready \
    --state-labels ready,ready-for-agent \
    --category-labels docs,refactor
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=state_label_conflict"
  assert_log_not_contains "$dir/glab.log" "issue update"

  dir="$(make_wrapper_fixture_dir wrapper-label-add-remove-overlap)"
  printf '%s\n' '{"iid":173,"labels":["ready-for-agent","refactor"]}' > "$dir/issue.json"
  run_wrapper_fixture "$dir" \
    label_reconcile \
    --repo git@gitlab.example.com:agents/skills.git \
    --issue-iid 173 \
    --add-labels refactor \
    --remove-labels refactor \
    --state-labels ready,ready-for-agent \
    --category-labels docs,refactor
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=add_remove_label_overlap"
  assert_log_not_contains "$dir/glab.log" "issue update"
}

test_safe_mr_json_returns_decision_grade_metadata_and_fails_closed() {
  local dir good_sha old_sha
  good_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  old_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

  dir="$(make_wrapper_fixture_dir wrapper-safe-mr-json)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" success "$good_sha" issue-173-gitlab-wrappers main
  run_wrapper_fixture "$dir" \
    safe_mr_json \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --project-path agents/skills
  assert_status 0
  assert_json_field sha "$good_sha"
  assert_json_field pipeline.status success
  assert_json_field source_branch issue-173-gitlab-wrappers
  assert_log_contains "$dir/glab.log" "glab mr view 59 -R git@gitlab.example.com:agents/skills.git -F json"

  dir="$(make_wrapper_fixture_dir wrapper-safe-missing-pipeline)"
  cat > "$dir/mr.json" <<JSON
{"iid":59,"state":"opened","sha":"$good_sha","source_branch":"issue-173","target_branch":"main","detailed_merge_status":"mergeable","web_url":"https://gitlab.example.com/agents/skills/-/merge_requests/59","project_id":16,"source_project_id":16,"target_project_id":16,"references":{"full":"agents/skills!59"},"pipeline":null}
JSON
  run_wrapper_fixture "$dir" \
    safe_mr_json \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --project-path agents/skills
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=missing_pipeline"

  dir="$(make_wrapper_fixture_dir wrapper-safe-control-char)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" success "$old_sha" "issue-\u0001bad" main
  run_wrapper_fixture "$dir" \
    safe_mr_json \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --project-path agents/skills
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=invalid_control_character:source_branch"
}

test_auto_merge_api_fallback_preserves_guards_and_blocks_builders() {
  local dir good_sha old_sha
  good_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  old_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-405)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-wrappers main
  FAKE_MR_MERGE_MODE=405 run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "AUTO_MERGE result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "via=api"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 -R git@gitlab.example.com:agents/skills.git --auto-merge --yes --sha $good_sha --remove-source-branch"
  assert_log_contains "$dir/glab.log" "glab api --hostname gitlab.example.com --method PUT projects/agents%2Fskills/merge_requests/59/merge --field sha=$good_sha --field auto_merge=true --field should_remove_source_branch=true --silent"
  assert_log_not_contains "$dir/glab.log" "approve"

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-missing-host)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-wrappers main
  FAKE_EXPECT_REPO=agents/skills FAKE_MR_MERGE_MODE=405 run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo agents/skills \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_validation_failure_without_glab_call "$dir" 64 missing_api_hostname

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-builder)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-wrappers main
  run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role builder
  assert_status 4
  assert_contains "$CAPTURE_OUTPUT" "reason=builder_no_finish_authority"
  assert_log_not_contains "$dir/glab.log" "mr merge"
  assert_log_not_contains "$dir/glab.log" "api"

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-stale-head)"
  write_safe_mr_json "$dir/mr.json" "$old_sha" running "$old_sha" issue-173-gitlab-wrappers main
  run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=head_changed"
  assert_log_not_contains "$dir/glab.log" "mr merge"
}

test_auto_merge_api_fallback_requests_source_branch_removal_on_glab_success() {
  local dir good_sha
  good_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-removal)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-wrappers main
  run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "AUTO_MERGE result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "via=glab"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 -R git@gitlab.example.com:agents/skills.git --auto-merge --yes --sha $good_sha --remove-source-branch"
  assert_log_not_contains "$dir/glab.log" "glab api"
}

test_post_merge_snapshot_reports_merged_closed_cleaned() {
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-merged)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" FAKE_SOURCE_REF_EXISTS=false run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88

  assert_status 0
  assert_json_field post_merge_snapshot.kind post-merge-snapshot
  assert_json_field post_merge_snapshot.mr.state merged
  assert_json_field post_merge_snapshot.default_branch.contains_reviewed_sha true
  assert_json_field post_merge_snapshot.default_branch.containment_satisfied_by reviewed_sha
  assert_json_field post_merge_snapshot.linked_issue.closure_status closed
  assert_json_field post_merge_snapshot.source_branch_cleanup.status cleaned_up
  assert_log_not_contains "$dir/glab.log" "mr merge"
  assert_log_not_contains "$dir/glab.log" "mr approve"
  assert_log_not_contains "$dir/glab.log" "issue close"
  assert_log_not_contains "$dir/git.log" "push"
  assert_log_not_contains "$dir/git.log" "branch"
}

test_post_merge_snapshot_reports_issue_closure_pending() {
  local dir reviewed
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  dir="$(make_snapshot_fixture_dir snapshot-closure-pending)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete
  write_snapshot_issue_json "$dir/issue.json" opened

  run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.state opened
  assert_json_field post_merge_snapshot.linked_issue.closure_status issue_closure_pending
  assert_json_array_contains post_merge_snapshot.pending_items issue_closure_pending
}

test_post_merge_snapshot_reports_branch_cleanup_pending() {
  local dir reviewed
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  dir="$(make_snapshot_fixture_dir snapshot-branch-cleanup-pending)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_SOURCE_REF_EXISTS=true run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88

  assert_status 0
  assert_json_field post_merge_snapshot.source_branch_cleanup.remote_ref_exists true
  assert_json_field post_merge_snapshot.source_branch_cleanup.policy delete_requested
  assert_json_field post_merge_snapshot.source_branch_cleanup.status source_branch_cleanup_pending
  assert_json_array_contains post_merge_snapshot.pending_items source_branch_cleanup_pending
  assert_log_not_contains "$dir/git.log" "push"
  assert_log_not_contains "$dir/git.log" "branch"
}

test_post_merge_snapshot_reports_retained_by_policy_or_unknown() {
  local dir reviewed
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  dir="$(make_snapshot_fixture_dir snapshot-retained)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main unknown
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_SOURCE_REF_EXISTS=true run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88

  assert_status 0
  assert_json_field post_merge_snapshot.source_branch_cleanup.policy unknown
  assert_json_field post_merge_snapshot.source_branch_cleanup.status source_branch_retained_by_policy_or_unknown
  assert_json_array_contains post_merge_snapshot.pending_items source_branch_retained_by_policy_or_unknown
}

test_post_merge_snapshot_reports_explicit_and_missing_containment() {
  local dir reviewed squash target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  squash=cccccccccccccccccccccccccccccccccccccccc
  target=dddddddddddddddddddddddddddddddddddddddd

  dir="$(make_snapshot_fixture_dir snapshot-squash-containment)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "$squash" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$squash" run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88
  assert_status 0
  assert_json_field post_merge_snapshot.default_branch.contains_reviewed_sha false
  assert_json_field post_merge_snapshot.default_branch.contains_squash_commit_sha true
  assert_json_field post_merge_snapshot.default_branch.containment_satisfied_by squash_commit_sha

  dir="$(make_snapshot_fixture_dir snapshot-missing-containment)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="" run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88
  assert_status 0
  assert_json_field post_merge_snapshot.default_branch.contains_reviewed_sha false
  assert_json_field post_merge_snapshot.default_branch.containment_satisfied_by none
  assert_json_array_contains post_merge_snapshot.pending_items default_branch_containment_missing

  dir="$(make_snapshot_fixture_dir snapshot-unknown-containment)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  FAKE_FETCH_FAIL=true run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88
  assert_status 0
  assert_json_field post_merge_snapshot.default_branch.fetch_status failed
  assert_json_field post_merge_snapshot.default_branch.contains_reviewed_sha_status unknown
  assert_json_array_contains post_merge_snapshot.pending_items default_branch_containment_unknown
}

test_post_merge_snapshot_fails_closed_on_non_git_fetchable_repo() {
  local dir reviewed
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

  # A host/path --repo form that glab accepts but git cannot fetch must fail
  # closed with a clear diagnostic naming the offending form, instead of
  # emitting an unknown-containment snapshot as success (issue #289).
  dir="$(make_snapshot_fixture_dir snapshot-non-fetchable-repo)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  SNAPSHOT_REPO="gitlab.example.com/agents/skills" FAKE_REPO_FETCHABLE=false \
    run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88
  assert_status 64
  assert_contains "$CAPTURE_OUTPUT" "reason=repo_not_git_fetchable:gitlab.example.com/agents/skills"
  # No snapshot JSON is emitted on the fail-closed path.
  assert_not_contains "$CAPTURE_OUTPUT" "post-merge-snapshot"
  # Stays read-only: no mutating git/glab attempts before failing closed.
  assert_log_not_contains "$dir/git.log" "fetch"
  assert_log_not_contains "$dir/glab.log" "mr merge"
}

test_post_merge_snapshot_reports_validation_not_run_cases() {
  local dir reviewed
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

  dir="$(make_snapshot_fixture_dir snapshot-validation-not-documented)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88
  assert_status 0
  assert_json_field post_merge_snapshot.validation.status not-run
  assert_json_field post_merge_snapshot.validation.not_run_reason not-documented
  assert_json_array_contains post_merge_snapshot.pending_items post_merge_validation_not_run

  dir="$(make_snapshot_fixture_dir snapshot-validation-missing-source)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88 --validation-command "true"
  assert_status 0
  assert_json_field post_merge_snapshot.validation.status not-run
  assert_json_field post_merge_snapshot.validation.not_run_reason missing-validation-source
  assert_json_array_contains post_merge_snapshot.pending_items post_merge_validation_not_run

  dir="$(make_snapshot_fixture_dir snapshot-validation-pass)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main retain
  write_snapshot_issue_json "$dir/issue.json" closed
  run_snapshot_fixture "$dir" "$reviewed" --issue-iid 88 --validation-command "true" --validation-source docs/agents/check-gate.md
  assert_status 0
  assert_json_field post_merge_snapshot.validation.status pass
  assert_json_field post_merge_snapshot.validation.not_run_reason N/A
}

test_post_merge_snapshot_resolves_colon_closes_via_description_scrape() {
  # Regression for RF-4: when the closes_issues preview is unavailable, the
  # widened scrape must still resolve a GitLab-valid colon form (`**Closes:**
  # #88`) so a merged MR reports observed closure_status instead of a false
  # not_linked.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-colon-closes-scrape)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete '**Closes:** #88'
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" FAKE_CLOSES_ISSUES_FAIL=true \
    run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid 88
  assert_json_field post_merge_snapshot.linked_issue.closure_status closed
}

test_post_merge_snapshot_uses_empty_closes_issues_preview() {
  # A successful-but-empty closes_issues preview is not overridden by the weaker
  # description scrape, even when the description carries a colon closing form.
  # Actual closure remains determined by observed issue state after merge.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-empty-closes-issues)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete '**Closes:** #88'
  write_snapshot_issue_json "$dir/issue.json" closed

  # No FAKE_CLOSES_ISSUES_FILE => the fake glab api returns an empty preview.
  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid ""
  assert_json_field post_merge_snapshot.linked_issue.closure_status not_linked
}

test_post_merge_snapshot_resolves_link_via_closes_issues_api() {
  # The closes_issues preview supplies a candidate even when the MR description
  # carries no closing keyword the scrape could match; issue state proves closure.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-closes-issues-api)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete 'See linked work item for context.'
  write_snapshot_issue_json "$dir/issue.json" closed
  write_snapshot_closes_issues_json "$dir/closes_issues.json" 88

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" \
    FAKE_CLOSES_ISSUES_FILE="$dir/closes_issues.json" \
    run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid 88
  assert_json_field post_merge_snapshot.linked_issue.closure_status closed
}

test_post_merge_snapshot_reports_link_undeterminable() {
  # When neither the closes_issues read nor the description scrape can resolve a
  # link, report link_undeterminable (not a false not_linked) and surface it.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-link-undeterminable)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete 'No closing reference here.'
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" FAKE_CLOSES_ISSUES_FAIL=true \
    run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid ""
  assert_json_field post_merge_snapshot.linked_issue.closure_status link_undeterminable
  assert_json_array_contains post_merge_snapshot.pending_items linked_issue_undeterminable
}

test_post_merge_snapshot_scrape_rejects_non_closing_fixe_form() {
  # The widened fallback regex matches GitLab's closing forms only. `Fixe #88`
  # is not a GitLab closing keyword and must not resolve a link; with
  # closes_issues unavailable this yields link_undeterminable, not a false link.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-fixe-non-closing)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete 'Fixe #88 is not a closing keyword.'
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" FAKE_CLOSES_ISSUES_FAIL=true \
    run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid ""
  assert_json_field post_merge_snapshot.linked_issue.closure_status link_undeterminable
}

test_post_merge_snapshot_scrape_requires_separator_before_issue_ref() {
  # MF-1 regression: a no-whitespace string like `Closes#88`, `Closes:#88` (bare
  # colon) or `fix#88` is not a GitLab closing reference and must not resolve a
  # link. GitLab's default closing pattern requires an optional colon followed by
  # one-or-more spaces before `#N`, so a colon alone is not a separator. With
  # closes_issues unavailable this yields link_undeterminable, not a false link.
  local dir reviewed target
  reviewed=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  dir="$(make_snapshot_fixture_dir snapshot-no-separator)"
  write_snapshot_mr_json "$dir/mr.json" merged "$reviewed" "" "" issue-176-post-merge-snapshot main delete 'Closes#88, Closes:#77 and fix#99 have no whitespace separator.'
  write_snapshot_issue_json "$dir/issue.json" closed

  FAKE_TARGET_SHA="$target" FAKE_CONTAINED_SHAS="$reviewed" FAKE_CLOSES_ISSUES_FAIL=true \
    run_snapshot_fixture "$dir" "$reviewed"

  assert_status 0
  assert_json_field post_merge_snapshot.linked_issue.iid ""
  assert_json_field post_merge_snapshot.linked_issue.closure_status link_undeterminable
}

test_native_helper_path_and_comparison_guidance
test_merge_watch_reports_merge_completion_terminals
test_merge_watch_fails_closed_on_control_char_body
test_merge_watch_reads_via_safe_mr_json_not_jq
test_finish_builder_handoff_never_approves_or_merges
test_finish_reports_issue_state_on_handoff_when_issue_iid_is_supplied
test_finish_yaml_format_reports_structured_handoff
test_finish_authorized_paths_are_sha_bound
test_finish_reports_issue_and_deletes_source_branches_after_direct_merge
test_finish_cleanup_flags_do_not_delete_branches_on_handoff_or_failures
test_finish_reports_post_mutation_git_failures
test_finish_remote_cleanup_requires_verified_default_containment
test_finish_blocks_local_cleanup_until_default_is_verified_safe
test_finish_rejects_unsafe_cleanup_paths_before_merge
test_finish_blocks_unsafe_states_before_mutation
test_wrappers_create_issue_and_mr_notes_without_body_leak
test_wrappers_create_and_update_mr_descriptions_with_control_validation
test_wrappers_delegate_file_backed_validation_to_shared_content_guard
test_wrappers_fail_closed_for_note_validation_without_glab_calls
test_label_reconcile_adds_and_removes_without_replace_assumption
test_safe_mr_json_returns_decision_grade_metadata_and_fails_closed
test_auto_merge_api_fallback_preserves_guards_and_blocks_builders
test_auto_merge_api_fallback_requests_source_branch_removal_on_glab_success
test_post_merge_snapshot_reports_merged_closed_cleaned
test_post_merge_snapshot_reports_issue_closure_pending
test_post_merge_snapshot_reports_branch_cleanup_pending
test_post_merge_snapshot_reports_retained_by_policy_or_unknown
test_post_merge_snapshot_reports_explicit_and_missing_containment
test_post_merge_snapshot_fails_closed_on_non_git_fetchable_repo
test_post_merge_snapshot_reports_validation_not_run_cases
test_post_merge_snapshot_resolves_colon_closes_via_description_scrape
test_post_merge_snapshot_uses_empty_closes_issues_preview
test_post_merge_snapshot_resolves_link_via_closes_issues_api
test_post_merge_snapshot_reports_link_undeterminable
test_post_merge_snapshot_scrape_rejects_non_closing_fixe_form
test_finish_retains_worktree_not_bound_to_recorded_source_branch
test_finish_retains_unregistered_and_remove_failed_worktrees
test_post_merge_snapshot_scrape_requires_separator_before_issue_ref

echo "gitlab-workflow-helpers: PASS"
