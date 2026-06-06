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

assert_yaml_field() {
  local field="$1" expected="$2"
  YAML_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const yaml = require('js-yaml');
const data = yaml.load(process.env.YAML_PAYLOAD || '');
const field = process.argv[2];
const expected = process.argv[3];
const actual = data?.[field];
if (String(actual) !== expected) {
  throw new Error(`expected YAML ${field}=${expected}, got ${actual}`);
}
NODE
}

make_fake_glab() {
  local bin_dir="$1"
  cat > "$bin_dir/glab" <<'FAKE_GLAB'
#!/usr/bin/env bash
set -euo pipefail
printf 'glab %s\n' "$*" >> "$FAKE_GLAB_LOG"
case "${1:-} ${2:-}" in
  "mr view")
    cat "$FAKE_MR_JSON_FILE"
    ;;
  "issue view")
    cat "$FAKE_ISSUE_JSON_FILE"
    ;;
  "ci status")
    cat "$FAKE_BRANCH_JSON_FILE"
    ;;
  "mr approve"|"mr merge")
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
  merge-base)
    [[ "${2:-}" == "--is-ancestor" ]] || { echo "unexpected git merge-base command: $*" >&2; exit 99; }
    if [[ -n "${FAKE_MERGE_BASE_ACCEPTS:-}" ]]; then
      [[ "${3:-}" == "$FAKE_MERGE_BASE_ACCEPTS" ]]
    else
      exit "${FAKE_MERGE_BASE_STATUS:-0}"
    fi
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
  local file="$1" state="$2" sha="$3" pipeline_status="$4" pipeline_sha="$5" merge_commit_sha="${6:-}" squash_commit_sha="${7:-}"
  local merge_line="" squash_line=""
  if [[ -n "$merge_commit_sha" ]]; then
    merge_line=", \"merge_commit_sha\": \"$merge_commit_sha\""
  fi
  if [[ -n "$squash_commit_sha" ]]; then
    squash_line=", \"squash_commit_sha\": \"$squash_commit_sha\""
  fi
  cat > "$file" <<JSON
{
  "iid": 59,
  "state": "$state",
  "sha": "$sha",
  "pipeline": {"id": 7, "status": "$pipeline_status", "sha": "$pipeline_sha", "web_url": "https://gitlab.example/pipelines/7"}$merge_line$squash_line
}
JSON
}

write_branch_json() {
  local file="$1" status="$2" sha="$3" jobs_json="${4:-[]}"
  cat > "$file" <<JSON
{"pipeline":{"id":7,"status":"$status","sha":"$sha"},"jobs":$jobs_json}
JSON
}

write_issue_json() {
  local file="$1" state="$2"
  cat > "$file" <<JSON
{"iid":88,"state":"$state","web_url":"https://gitlab.example/group/project/-/issues/88"}
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
    FAKE_ISSUE_JSON_FILE="${FAKE_ISSUE_JSON_FILE:-$dir/issue.json}" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    FAKE_GIT_LOG="$dir/git.log" \
    FAKE_GIT_STATUS="${FAKE_GIT_STATUS:-}" \
    FAKE_WORKTREE_STATUS="${FAKE_WORKTREE_STATUS:-}" \
    FAKE_MERGE_BASE_STATUS="${FAKE_MERGE_BASE_STATUS:-0}" \
    FAKE_MERGE_BASE_ACCEPTS="${FAKE_MERGE_BASE_ACCEPTS:-}" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab-local/scripts/gitlab-finish-mr.sh" "$@"
}

make_wrapper_fake_glab() {
  local bin_dir="$1"
  cat > "$bin_dir/glab" <<'FAKE_GLAB'
#!/usr/bin/env bash
set -euo pipefail

log_args() {
  local redaction_label=""
  printf 'glab' >> "$FAKE_GLAB_LOG"
  for arg in "$@"; do
    if [[ -n "$redaction_label" ]]; then
      printf ' <%s-redacted>' "$redaction_label" >> "$FAKE_GLAB_LOG"
      redaction_label=""
      continue
    fi
    printf ' %s' "$arg" >> "$FAKE_GLAB_LOG"
    case "$arg" in
      --message|-m) redaction_label="message" ;;
      --description|-d) redaction_label="description" ;;
    esac
  done
  printf '\n' >> "$FAKE_GLAB_LOG"
}

expect_repo_and_message() {
  local repo="" message=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo)
        repo="${2:-}"; shift 2 ;;
      --message|-m)
        message="${2:-}"; shift 2 ;;
      *)
        shift ;;
    esac
  done
  [[ "$repo" == "$FAKE_EXPECT_REPO" ]] || { echo "wrong repo: $repo" >&2; exit 98; }
  [[ "$message" == "$FAKE_EXPECT_MESSAGE" ]] || { echo "wrong message" >&2; exit 98; }
}

expect_repo_and_description() {
  local repo="" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo)
        repo="${2:-}"; shift 2 ;;
      --description|-d)
        description="${2:-}"; shift 2 ;;
      *)
        shift ;;
    esac
  done
  [[ "$repo" == "$FAKE_EXPECT_REPO" ]] || { echo "wrong repo: $repo" >&2; exit 98; }
  [[ "$description" == "$FAKE_EXPECT_DESCRIPTION" ]] || { echo "wrong description" >&2; exit 98; }
}

expect_mr_create() {
  local repo="" target="" source="" title="" description="" saw_draft=false saw_push=false saw_yes=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo)
        repo="${2:-}"; shift 2 ;;
      --target-branch|-b)
        target="${2:-}"; shift 2 ;;
      --source-branch|-s)
        source="${2:-}"; shift 2 ;;
      --title|-t)
        title="${2:-}"; shift 2 ;;
      --description|-d)
        description="${2:-}"; shift 2 ;;
      --draft)
        saw_draft=true; shift ;;
      --push)
        saw_push=true; shift ;;
      --yes|-y)
        saw_yes=true; shift ;;
      *)
        shift ;;
    esac
  done
  [[ "$repo" == "$FAKE_EXPECT_REPO" ]] || { echo "wrong repo: $repo" >&2; exit 98; }
  [[ "$target" == "$FAKE_EXPECT_TARGET" ]] || { echo "wrong target: $target" >&2; exit 98; }
  [[ "$source" == "$FAKE_EXPECT_SOURCE" ]] || { echo "wrong source: $source" >&2; exit 98; }
  [[ "$title" == "$FAKE_EXPECT_TITLE" ]] || { echo "wrong title: $title" >&2; exit 98; }
  [[ "$description" == "$FAKE_EXPECT_DESCRIPTION" ]] || { echo "wrong description" >&2; exit 98; }
  [[ "$saw_draft" == "true" ]] || { echo "missing draft flag" >&2; exit 98; }
  [[ "$saw_push" == "true" ]] || { echo "missing push flag" >&2; exit 98; }
  [[ "$saw_yes" == "true" ]] || { echo "missing yes flag" >&2; exit 98; }
}

log_args "$@"
case "${1:-} ${2:-}" in
  "mr create")
    shift 2
    expect_mr_create "$@"
    ;;
  "mr update")
    [[ "${3:-}" == "$FAKE_EXPECT_MR" ]] || { echo "wrong mr: ${3:-}" >&2; exit 98; }
    shift 3
    expect_repo_and_description "$@"
    ;;
  "issue note")
    [[ "${3:-}" == "$FAKE_EXPECT_ISSUE" ]] || { echo "wrong issue: ${3:-}" >&2; exit 98; }
    shift 3
    expect_repo_and_message "$@"
    ;;
  "mr note")
    [[ "${3:-}" == "create" ]] || { echo "unexpected mr note verb: ${3:-}" >&2; exit 98; }
    [[ "${4:-}" == "$FAKE_EXPECT_MR" ]] || { echo "wrong mr: ${4:-}" >&2; exit 98; }
    shift 4
    expect_repo_and_message "$@"
    ;;
  "issue view")
    cat "$FAKE_ISSUE_JSON_FILE"
    ;;
  "issue update")
    ;;
  "mr view")
    cat "$FAKE_MR_JSON_FILE"
    ;;
  "mr merge")
    case "${FAKE_MR_MERGE_MODE:-success}" in
      success) ;;
      405)
        echo "405 Method Not Allowed" >&2
        exit 1
        ;;
      fail)
        echo "merge failed" >&2
        exit 1
        ;;
      *)
        echo "unknown fake merge mode: ${FAKE_MR_MERGE_MODE:-}" >&2
        exit 98
        ;;
    esac
    ;;
  "api "*)
    ;;
  *)
    echo "unexpected glab command: $*" >&2
    exit 99
    ;;
esac
FAKE_GLAB
  chmod +x "$bin_dir/glab"
}

make_wrapper_fixture_dir() {
  local name="$1"
  local dir="$TMPDIR/$name"
  mkdir -p "$dir/bin"
  make_wrapper_fake_glab "$dir/bin"
  : > "$dir/glab.log"
  printf '%s\n' "$dir"
}

write_safe_mr_json() {
  local file="$1" sha="$2" pipeline_status="$3" pipeline_sha="$4" source_branch="${5:-issue-173}" target_branch="${6:-main}"
  cat > "$file" <<JSON
{
  "iid": 59,
  "state": "opened",
  "draft": false,
  "sha": "$sha",
  "source_branch": "$source_branch",
  "target_branch": "$target_branch",
  "detailed_merge_status": "mergeable",
  "web_url": "https://gitlab.example.com/agents/skills/-/merge_requests/59",
  "project_id": 16,
  "source_project_id": 16,
  "target_project_id": 16,
  "references": {"full": "agents/skills!59"},
  "pipeline": {"id": 7, "status": "$pipeline_status", "sha": "$pipeline_sha", "web_url": "https://gitlab.example.com/agents/skills/-/pipelines/7"}
}
JSON
}

run_wrapper_fixture() {
  local dir="$1"
  shift
  run_capture env \
    FAKE_MR_JSON_FILE="${FAKE_MR_JSON_FILE:-$dir/mr.json}" \
    FAKE_ISSUE_JSON_FILE="${FAKE_ISSUE_JSON_FILE:-$dir/issue.json}" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    FAKE_EXPECT_REPO="${FAKE_EXPECT_REPO:-git@gitlab.example.com:agents/skills.git}" \
    FAKE_EXPECT_MESSAGE="${FAKE_EXPECT_MESSAGE:-}" \
    FAKE_EXPECT_ISSUE="${FAKE_EXPECT_ISSUE:-173}" \
    FAKE_EXPECT_MR="${FAKE_EXPECT_MR:-59}" \
    FAKE_EXPECT_DESCRIPTION="${FAKE_EXPECT_DESCRIPTION:-}" \
    FAKE_EXPECT_TITLE="${FAKE_EXPECT_TITLE:-Draft title}" \
    FAKE_EXPECT_SOURCE="${FAKE_EXPECT_SOURCE:-issue-183}" \
    FAKE_EXPECT_TARGET="${FAKE_EXPECT_TARGET:-main}" \
    FAKE_MR_MERGE_MODE="${FAKE_MR_MERGE_MODE:-success}" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab-local/scripts/gitlab-wrappers.sh" "$@"
}

assert_json_field() {
  local field="$1" expected="$2"
  JSON_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
let value = data;
for (const key of path) value = value?.[key];
const actual = value === undefined || value === null ? '' : String(value);
if (actual !== process.argv[3]) {
  throw new Error(`expected JSON ${process.argv[2]}=${process.argv[3]}, got ${actual}`);
}
NODE
}

assert_validation_failure_without_glab_call() {
  local dir="$1" expected_status="$2" reason="$3"
  assert_status "$expected_status"
  assert_contains "$CAPTURE_OUTPUT" "reason=$reason"
  assert_log_not_contains "$dir/glab.log" "glab"
}

assert_json_array_contains() {
  local field="$1" expected="$2"
  JSON_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
let value = data;
for (const key of path) value = value?.[key];
if (!Array.isArray(value) || !value.includes(process.argv[3])) {
  throw new Error(`expected JSON array ${process.argv[2]} to contain ${process.argv[3]}, got ${JSON.stringify(value)}`);
}
NODE
}

make_snapshot_fake_glab() {
  local bin_dir="$1"
  cat > "$bin_dir/glab" <<'FAKE_GLAB'
#!/usr/bin/env bash
set -euo pipefail
printf 'glab %s\n' "$*" >> "$FAKE_GLAB_LOG"
case "${1:-} ${2:-}" in
  "mr view")
    cat "$FAKE_MR_JSON_FILE"
    ;;
  "issue view")
    cat "$FAKE_ISSUE_JSON_FILE"
    ;;
  "mr approve"|"mr merge"|"issue close"|"issue update")
    echo "mutating glab command attempted: $*" >&2
    exit 97
    ;;
  *)
    echo "unexpected glab command: $*" >&2
    exit 99
    ;;
esac
FAKE_GLAB
  chmod +x "$bin_dir/glab"
}

make_snapshot_fake_git() {
  local bin_dir="$1"
  cat > "$bin_dir/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$FAKE_GIT_LOG"
case "${1:-}" in
  fetch)
    [[ "${FAKE_FETCH_FAIL:-false}" != "true" ]] || exit 1
    ;;
  rev-parse)
    [[ "${2:-}" == "FETCH_HEAD" ]] || { echo "unexpected git rev-parse: $*" >&2; exit 99; }
    printf '%s\n' "$FAKE_TARGET_SHA"
    ;;
  merge-base)
    [[ "${2:-}" == "--is-ancestor" ]] || { echo "unexpected git merge-base: $*" >&2; exit 99; }
    sha="${3:-}"
    case ",${FAKE_CONTAINED_SHAS:-}," in
      *,"$sha",*) exit 0 ;;
      *) exit 1 ;;
    esac
    ;;
  ls-remote)
    ref="${3:-}"
    if [[ "$ref" == "refs/heads/${FAKE_SOURCE_BRANCH:-issue-176-post-merge-snapshot}" && "${FAKE_SOURCE_REF_EXISTS:-false}" == "true" ]]; then
      printf '%s\t%s\n' "${FAKE_SOURCE_SHA:-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee}" "$ref"
    fi
    ;;
  push|branch)
    echo "mutating git command attempted: $*" >&2
    exit 97
    ;;
  *)
    echo "unexpected git command: $*" >&2
    exit 99
    ;;
esac
FAKE_GIT
  chmod +x "$bin_dir/git"
}

make_snapshot_fixture_dir() {
  local name="$1"
  local dir="$TMPDIR/$name"
  mkdir -p "$dir/bin"
  make_snapshot_fake_glab "$dir/bin"
  make_snapshot_fake_git "$dir/bin"
  : > "$dir/glab.log"
  : > "$dir/git.log"
  printf '%s\n' "$dir"
}

write_snapshot_issue_json() {
  local file="$1" state="$2"
  cat > "$file" <<JSON
{"iid":88,"state":"$state","web_url":"https://gitlab.example.com/agents/skills/-/work_items/88"}
JSON
}

write_snapshot_mr_json() {
  local file="$1" state="$2" head_sha="$3" merge_sha="$4" squash_sha="$5" source_branch="$6" target_branch="$7" cleanup_policy="$8" description="${9:-Closes #88}"
  local merge_json="null" squash_json="null" should_remove="null" force_remove="null" remove_source="null"
  [[ -z "$merge_sha" ]] || merge_json="\"$merge_sha\""
  [[ -z "$squash_sha" ]] || squash_json="\"$squash_sha\""
  case "$cleanup_policy" in
    delete)
      should_remove="true"; force_remove="false"; remove_source="true" ;;
    retain)
      should_remove="false"; force_remove="false"; remove_source="false" ;;
    unknown)
      ;;
    *)
      fail "unknown snapshot cleanup policy $cleanup_policy" ;;
  esac
  cat > "$file" <<JSON
{
  "iid": 59,
  "state": "$state",
  "draft": false,
  "sha": "$head_sha",
  "merge_commit_sha": $merge_json,
  "squash_commit_sha": $squash_json,
  "source_branch": "$source_branch",
  "target_branch": "$target_branch",
  "should_remove_source_branch": $should_remove,
  "force_remove_source_branch": $force_remove,
  "remove_source_branch": $remove_source,
  "description": "$description",
  "web_url": "https://gitlab.example.com/agents/skills/-/merge_requests/59"
}
JSON
}

run_snapshot_fixture() {
  local dir="$1" reviewed_sha="$2"
  shift 2
  run_capture env \
    FAKE_MR_JSON_FILE="$dir/mr.json" \
    FAKE_ISSUE_JSON_FILE="$dir/issue.json" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    FAKE_GIT_LOG="$dir/git.log" \
    FAKE_TARGET_SHA="${FAKE_TARGET_SHA:-dddddddddddddddddddddddddddddddddddddddd}" \
    FAKE_CONTAINED_SHAS="${FAKE_CONTAINED_SHAS-$reviewed_sha}" \
    FAKE_SOURCE_BRANCH="${FAKE_SOURCE_BRANCH:-issue-176-post-merge-snapshot}" \
    FAKE_SOURCE_REF_EXISTS="${FAKE_SOURCE_REF_EXISTS:-false}" \
    FAKE_SOURCE_SHA="${FAKE_SOURCE_SHA:-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee}" \
    FAKE_FETCH_FAIL="${FAKE_FETCH_FAIL:-false}" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab-local/scripts/gitlab-post-merge-snapshot.sh" \
      --repo git@gitlab.example.com:agents/skills.git \
      --mr-iid 59 \
      --reviewed-sha "$reviewed_sha" \
      "$@"
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
  assert_log_contains "$dir/glab.log" "glab mr merge 59 --yes --sha abc123 --auto-merge=false"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"

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
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
}

test_finish_reports_issue_and_deletes_source_branches_after_direct_merge() {
  local dir
  dir="$(make_fixture_dir finish-merge-cleanup)"
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
    --issue-iid 88 \
    --delete-local-source-branch \
    --delete-remote-source-branch

  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "via=glab-fallback"
  assert_contains "$CAPTURE_OUTPUT" "issue_state=closed"
  assert_contains "$CAPTURE_OUTPUT" "branch=local_deleted,remote_deleted"
  assert_log_contains "$dir/glab.log" "glab issue view 88 -F json"
  assert_log_contains "$dir/git.log" "git branch -d build/61"
  assert_log_contains "$dir/git.log" "git push origin --delete build/61"
}

test_finish_blocks_local_cleanup_until_default_is_verified_safe() {
  local dir

  dir="$(make_fixture_dir finish-cleanup-dirty-default)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_GIT_STATUS=' M coordinator-file' run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --worktree-path /tmp/clean-worktree \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "FINISH_MR result=merged"
  assert_contains "$CAPTURE_OUTPUT" "worktree=blocked_default_not_verified"
  assert_contains "$CAPTURE_OUTPUT" "branch=local_delete_blocked_default_not_verified"
  assert_log_not_contains "$dir/git.log" "git worktree remove /tmp/clean-worktree"
  assert_log_not_contains "$dir/git.log" "git branch -d build/61"

  dir="$(make_fixture_dir finish-cleanup-merge-sha)"
  write_mr_json "$dir/mr.json" opened abc123 success abc123 merge999
  write_branch_json "$dir/branch.json" success abc123
  FAKE_MERGE_BASE_ACCEPTS=merge999 run_finish_fixture "$dir" \
    --mr-iid 59 \
    --reviewed-sha abc123 \
    --merge-authority "reviewer may merge" \
    --caller-role authorized-parent \
    --source-branch build/61 \
    --default-branch main \
    --worktree-path /tmp/clean-worktree \
    --delete-local-source-branch
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "worktree=removed"
  assert_contains "$CAPTURE_OUTPUT" "branch=local_deleted"
  assert_log_contains "$dir/git.log" "git merge-base --is-ancestor abc123 main"
  assert_log_contains "$dir/git.log" "git merge-base --is-ancestor merge999 main"
  assert_log_contains "$dir/git.log" "git worktree remove /tmp/clean-worktree"
  assert_log_contains "$dir/git.log" "git branch -d build/61"
}

test_finish_cleanup_flags_do_not_delete_branches_on_handoff_or_failures() {
  local dir

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
  write_mr_json "$dir/mr.json" opened abc123 success abc123
  write_branch_json "$dir/branch.json" success abc123
  FAKE_WORKTREE_STATUS=' M uncommitted-file' run_finish_fixture "$dir" \
    --mr-iid 59 --reviewed-sha abc123 --merge-authority "reviewer may merge" --caller-role reviewer --source-branch build/61 --default-branch main --worktree-path /tmp/dirty-worktree
  assert_status 5
  assert_contains "$CAPTURE_OUTPUT" "reason=dirty_worktree_cleanup"
  assert_log_not_contains "$dir/glab.log" "merge"
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
  assert_log_contains "$dir/glab.log" "glab mr note create 59 -R git@gitlab.example.com:agents/skills.git --message <message-redacted>"
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
  write_safe_mr_json "$dir/mr.json" "$good_sha" success "$good_sha" issue-173-gitlab-local-wrappers main
  run_wrapper_fixture "$dir" \
    safe_mr_json \
    --repo git@gitlab.example.com:agents/skills.git \
    --mr-iid 59 \
    --project-path agents/skills
  assert_status 0
  assert_json_field sha "$good_sha"
  assert_json_field pipeline.status success
  assert_json_field source_branch issue-173-gitlab-local-wrappers
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
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-local-wrappers main
  FAKE_MR_MERGE_MODE=405 run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-local-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_status 0
  assert_contains "$CAPTURE_OUTPUT" "AUTO_MERGE result=auto_merge_queued"
  assert_contains "$CAPTURE_OUTPUT" "via=api"
  assert_log_contains "$dir/glab.log" "glab mr merge 59 -R git@gitlab.example.com:agents/skills.git --auto-merge --yes --sha $good_sha"
  assert_log_contains "$dir/glab.log" "glab api --hostname gitlab.example.com --method PUT projects/agents%2Fskills/merge_requests/59/merge --field sha=$good_sha --field auto_merge=true --silent"
  assert_log_not_contains "$dir/glab.log" "approve"

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-missing-host)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-local-wrappers main
  FAKE_EXPECT_REPO=agents/skills FAKE_MR_MERGE_MODE=405 run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo agents/skills \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-local-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_validation_failure_without_glab_call "$dir" 64 missing_api_hostname

  dir="$(make_wrapper_fixture_dir wrapper-auto-merge-builder)"
  write_safe_mr_json "$dir/mr.json" "$good_sha" running "$good_sha" issue-173-gitlab-local-wrappers main
  run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-local-wrappers \
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
  write_safe_mr_json "$dir/mr.json" "$old_sha" running "$old_sha" issue-173-gitlab-local-wrappers main
  run_wrapper_fixture "$dir" \
    auto_merge_api_fallback \
    --repo git@gitlab.example.com:agents/skills.git \
    --project-path agents/skills \
    --mr-iid 59 \
    --reviewed-sha "$good_sha" \
    --source-branch issue-173-gitlab-local-wrappers \
    --target-branch main \
    --merge-authority "queue auto-merge" \
    --authority-source "parent task prompt: queue auto-merge" \
    --authority-verified true \
    --caller-role authorized-parent
  assert_status 2
  assert_contains "$CAPTURE_OUTPUT" "reason=head_changed"
  assert_log_not_contains "$dir/glab.log" "mr merge"
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

test_ci_watch_passes_for_matching_green_pipeline
test_ci_watch_fails_closed_for_head_change_red_stale_and_unknown_state
test_finish_builder_handoff_never_approves_or_merges
test_finish_reports_issue_state_on_handoff_when_issue_iid_is_supplied
test_finish_yaml_format_reports_structured_handoff
test_finish_authorized_paths_are_sha_bound
test_finish_reports_issue_and_deletes_source_branches_after_direct_merge
test_finish_cleanup_flags_do_not_delete_branches_on_handoff_or_failures
test_finish_blocks_local_cleanup_until_default_is_verified_safe
test_finish_blocks_unsafe_states_before_mutation
test_wrappers_create_issue_and_mr_notes_without_body_leak
test_wrappers_create_and_update_mr_descriptions_with_control_validation
test_wrappers_fail_closed_for_note_validation_without_glab_calls
test_label_reconcile_adds_and_removes_without_replace_assumption
test_safe_mr_json_returns_decision_grade_metadata_and_fails_closed
test_auto_merge_api_fallback_preserves_guards_and_blocks_builders
test_post_merge_snapshot_reports_merged_closed_cleaned
test_post_merge_snapshot_reports_issue_closure_pending
test_post_merge_snapshot_reports_branch_cleanup_pending
test_post_merge_snapshot_reports_retained_by_policy_or_unknown
test_post_merge_snapshot_reports_explicit_and_missing_containment
test_post_merge_snapshot_reports_validation_not_run_cases

echo "gitlab-workflow-helpers: PASS"
