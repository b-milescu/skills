# Shared fake GitLab/Git fixture factories for shell regression tests.
# Source from tests after setting REPO_ROOT and TEST_TMPDIR.

_GITLAB_FIXTURE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tests/lib/command-capture.sh
source "$_GITLAB_FIXTURE_LIB_DIR/command-capture.sh"
unset _GITLAB_FIXTURE_LIB_DIR

: "${REPO_ROOT:?REPO_ROOT must be set before sourcing gitlab-fixtures.sh}"
: "${TEST_TMPDIR:?TEST_TMPDIR must be set before sourcing gitlab-fixtures.sh}"

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
  local dir="$TEST_TMPDIR/$name"
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
  local dir="$1" expected_sha="$2" timeout="${3:-0}" format="${4:-human}"
  run_capture env \
    FAKE_MR_JSON_FILE="$dir/mr.json" \
    FAKE_BRANCH_JSON_FILE="$dir/branch.json" \
    FAKE_GLAB_LOG="$dir/glab.log" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab/scripts/gitlab-ci-watch.sh" \
      --mr-iid 59 \
      --source-branch build/61 \
      --reviewed-sha "$expected_sha" \
      --timeout-seconds "$timeout" \
      --poll-seconds 0 \
      --format "$format"
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
    "$REPO_ROOT/gitlab/scripts/gitlab-finish-mr.sh" "$@"
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
  local dir="$TEST_TMPDIR/$name"
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
    GITLAB_CONTENT_GUARD="${GITLAB_CONTENT_GUARD:-}" \
    FAKE_CONTENT_GUARD_LOG="${FAKE_CONTENT_GUARD_LOG:-}" \
    PATH="$dir/bin:$PATH" \
    "$REPO_ROOT/gitlab/scripts/gitlab-wrappers.sh" "$@"
}

assert_validation_failure_without_glab_call() {
  local dir="$1" expected_status="$2" reason="$3"
  assert_status "$expected_status"
  assert_contains "$CAPTURE_OUTPUT" "reason=$reason"
  assert_log_not_contains "$dir/glab.log" "glab"
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
  local dir="$TEST_TMPDIR/$name"
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
    "$REPO_ROOT/gitlab/scripts/gitlab-post-merge-snapshot.sh" \
      --repo git@gitlab.example.com:agents/skills.git \
      --mr-iid 59 \
      --reviewed-sha "$reviewed_sha" \
      "$@"
}
