#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_capture() {
  set +e
  CAPTURE_OUTPUT="$("$@" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain '$needle'; got: $haystack"
}

assert_log_contains() {
  local file="$1"
  local needle="$2"
  [[ -f "$file" ]] || fail "missing log $file"
  grep -Fq -- "$needle" "$file" || fail "expected $file to contain '$needle'; got: $(cat "$file")"
}

assert_log_not_contains() {
  local file="$1"
  local needle="$2"
  [[ ! -f "$file" ]] || ! grep -Fq -- "$needle" "$file" || fail "expected $file not to contain '$needle'; got: $(cat "$file")"
}

write_json() {
  local file="$1"
  shift
  printf '%s\n' "$*" > "$file"
}

make_fake_glab() {
  local bin_dir="$1"
  cat > "$bin_dir/glab" <<'FAKE_GLAB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "mr view")
    cat "$FAKE_MR_JSON_FILE"
    ;;
  "ci status")
    cat "$FAKE_BRANCH_JSON_FILE"
    ;;
  "mr approve")
    printf 'glab %s\n' "$*" >> "$FAKE_GLAB_LOG"
    ;;
  "mr merge")
    printf 'glab %s\n' "$*" >> "$FAKE_GLAB_LOG"
    ;;
  *)
    echo "unexpected glab command: $*" >&2
    exit 99
    ;;
esac
FAKE_GLAB
  chmod +x "$bin_dir/glab"
}

make_fake_git() {
  local bin_dir="$1"
  cat > "$bin_dir/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail
worktree=""
if [[ "${1:-}" == "-C" ]]; then
  worktree="$2"
  shift 2
fi
printf 'git %s%s\n' "${worktree:+-C $worktree }" "$*" >> "$FAKE_GIT_LOG"
case "${1:-}" in
  status)
    if [[ -n "$worktree" ]]; then
      printf '%s' "${FAKE_WORKTREE_STATUS:-}"
    else
      printf '%s' "${FAKE_GIT_STATUS:-}"
    fi
    ;;
  fetch|checkout|pull|branch|push)
    ;;
  worktree)
    [[ "${2:-}" == "remove" ]] || { echo "unexpected git worktree command: $*" >&2; exit 99; }
    ;;
  *)
    echo "unexpected git command: ${worktree:+-C $worktree }$*" >&2
    exit 99
    ;;
esac
FAKE_GIT
  chmod +x "$bin_dir/git"
}

make_fixture_dir() {
  local name="$1"
  local dir="$TMPDIR/$name"
  mkdir -p "$dir/bin"
  make_fake_glab "$dir/bin"
  make_fake_git "$dir/bin"
  : > "$dir/glab.log"
  : > "$dir/git.log"
  printf '%s\n' "$dir"
}

write_mr_json() {
  local file="$1" state="$2" sha="$3" pipeline_status="$4" pipeline_sha="$5"
  cat > "$file" <<JSON
{
  "iid": 59,
  "state": "$state",
  "sha": "$sha",
  "pipeline": {"id": 7, "status": "$pipeline_status", "sha": "$pipeline_sha", "web_url": "https://gitlab.example/pipelines/7"}
}
JSON
}

write_branch_json() {
  local file="$1" status="$2" sha="$3" jobs_json="${4:-[]}"
  cat > "$file" <<JSON
{"pipeline":{"id":7,"status":"$status","sha":"$sha"},"jobs":$jobs_json}
JSON
}

run_ci_watch_fixture() {
  local dir="$1" expected_sha="$2" timeout="${3:-0}"
  run_capture env \
    FAKE_MR_JSON_FILE="$dir/mr.json" \
    FAKE_BRANCH_JSON_FILE="$dir/branch.json" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab-local/scripts/gitlab-ci-watch.sh" \
      --mr-iid 59 \
      --source-branch build/61 \
      --reviewed-sha "$expected_sha" \
      --timeout-seconds "$timeout" \
      --poll-seconds 0
}

run_finish_fixture() {
  local dir="$1"
  shift
  run_capture env \
    FAKE_MR_JSON_FILE="$dir/mr.json" \
    FAKE_BRANCH_JSON_FILE="$dir/branch.json" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    FAKE_GIT_LOG="$dir/git.log" \
    FAKE_GIT_STATUS="${FAKE_GIT_STATUS:-}" \
    FAKE_WORKTREE_STATUS="${FAKE_WORKTREE_STATUS:-}" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab-local/scripts/gitlab-finish-mr.sh" "$@"
}

test_ci_watch_passes_for_matching_green_pipeline() {
  local dir
  dir="$(make_fixture_dir ci-success)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123

  run_ci_watch_fixture "$dir" abc123

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "CI_WATCH result=pass"
  assert_contains "$CAPTURE_OUTPUT" "sha=abc123"
}

test_ci_watch_fails_closed_for_head_change_red_stale_and_unknown_state() {
  local dir

  dir="$(make_fixture_dir ci-head-change)"
  write_mr_json "$dir/mr.json" opened def456 success def456
  write_branch_json "$dir/branch.json" success def456
  run_ci_watch_fixture "$dir" abc123
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "result=head_changed"

  dir="$(make_fixture_dir ci-red)"
  write_mr_json "$dir/mr.json" opened abc123 failed abc123
  write_branch_json "$dir/branch.json" failed abc123 '[{"name":"check","status":"failed","allow_failure":false}]'
  run_ci_watch_fixture "$dir" abc123
  assert_status 1
  assert_contains "$CAPTURE_OUTPUT" "result=fail"

  dir="$(make_fixture_dir ci-stale)"
  write_mr_json "$dir/mr.json" opened abc123 success old999
  write_branch_json "$dir/branch.json" success old999
  run_ci_watch_fixture "$dir" abc123
  assert_status 3
  assert_contains "$CAPTURE_OUTPUT" "result=stale_ci"

  dir="$(make_fixture_dir ci-unknown-state)"
  write_mr_json "$dir/mr.json" closed abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_ci_watch_fixture "$dir" abc123
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=unknown_mr_state"
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
  assert_log_not_contains "$dir/glab.log" "approve"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_finish_authorized_paths_are_sha_bound() {
  local dir
  dir="$(make_fixture_dir finish-reviewer-merge)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role reviewer \
    --source-branch build/61 \
    --default-branch main \
    --approve-as-reviewer

  assert_status 0
  assert_log_contains "$dir/glab.log" "glab mr approve 59 --sha abc123"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --yes --sha abc123"

  dir="$(make_fixture_dir finish-auto-merge)"
  write_mr_json "$dir/mr.json" opened abc123 running abc123
  write_branch_json "$dir/branch.json" running abc123

  run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "queue auto-merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main

  assert_status 0
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --auto-merge --yes --sha abc123"
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

  dir="$(make_fixture_dir finish-missing-authority)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --caller-role reviewer --source-branch build/61 --default-branch main
  assert_status 4
  assert_contains "$CAPTURE_OUTPUT" "reason=missing_merge_authority"
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
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_WORKTREE_STATUS=' M uncommitted-file' run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main --worktree-path /tmp/dirty-worktree
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=dirty_worktree_cleanup"
  assert_log_not_contains "$dir/glab.log" "merge"
}

test_ci_watch_passes_for_matching_green_pipeline
test_ci_watch_fails_closed_for_head_change_red_stale_and_unknown_state
test_finish_builder_handoff_never_approves_or_merges
test_finish_authorized_paths_are_sha_bound
test_finish_blocks_unsafe_states_before_mutation

echo "gitlab-workflow-helpers: PASS"
