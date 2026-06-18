#!/usr/bin/env bash
# SHA-pinned GitLab merge-completion watcher helper.
#
# Polls a bound MR to a terminal merge state over the control-char-safe
# `safe_mr_json` projection (gitlab-wrappers.sh) instead of a raw
# `glab ... -F json | jq` read of the full MR body. The full body can carry raw
# control characters (a Review Packet description) that break `jq`/`JSON.parse`,
# so a hand-rolled background waiter parse-errors on every poll and silently
# never observes the merge. `safe_mr_json` validates and projects only the
# decision-grade fields and fails closed on control-char / JSON / SHA / pipeline
# / merge-status drift, so this watcher surfaces a clear terminal instead of
# looping forever (issue #298; retro 2026-06-15 RF-1).
#
# Safe to invoke from a detached background bash loop (absolute-path invocation;
# no `skill://` dependency at call time per the non-OMP rule) and from
# foreground. References — does not duplicate — the slim guard-read /
# `safe_mr_json` guidance in gitlab/SKILL.md and
# gitlab/reference/snippet-transports.md (#286 lineage).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WRAPPERS="${GITLAB_MERGE_WATCH_WRAPPERS:-$SCRIPT_DIR/gitlab-wrappers.sh}"

usage() {
  cat <<'USAGE'
Usage: gitlab-merge-watch.sh --mr-iid <iid> --repo <repo> --project-path <group/project> --reviewed-sha <sha> [options]

Required:
  --mr-iid <iid>               Merge request IID to watch.
  --repo <repo>                GitLab repository URL/path accepted by glab.
  --project-path <group/proj>  Project path for safe_mr_json binding (e.g. agents/skills).
  --reviewed-sha <sha>         40-hex reviewed/candidate head SHA the MR must keep.

Options:
  --source-branch <branch>     Expected MR source branch (extra binding check).
  --target-branch <branch>     Expected MR target branch (extra binding check).
  --timeout-seconds <seconds>  Max wait time. Default: 1800.
  --poll-seconds <seconds>     Poll interval. Default: 15.
  --format <human|yaml>        Output format. Default: human.
  -h, --help                   Show this help.

Terminal results (one parseable line; only `merged` is exit 0):
  merged            (exit 0)   MR merged at the reviewed SHA; emits merge_commit.
  ci_failed         (exit 1)   reviewed-SHA pipeline failed/canceled; auto-merge will not complete.
  head_changed      (exit 2)   MR head drifted off the reviewed SHA.
  blocked           (exit 3)   safe read failed closed (control-char / binding / SHA drift).
  timeout           (exit 4)   no terminal reached within --timeout-seconds.
  unknown_mr_state  (exit 5)   MR left "opened"/"merged" without merging (e.g. closed).
USAGE
}

mr_iid=""
repo=""
project_path=""
reviewed_sha=""
source_branch=""
target_branch=""
timeout_seconds=1800
poll_seconds=15
output_format="human"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr-iid) mr_iid="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    --project-path) project_path="${2:-}"; shift 2 ;;
    --reviewed-sha) reviewed_sha="${2:-}"; shift 2 ;;
    --source-branch) source_branch="${2:-}"; shift 2 ;;
    --target-branch) target_branch="${2:-}"; shift 2 ;;
    --timeout-seconds) timeout_seconds="${2:-}"; shift 2 ;;
    --poll-seconds) poll_seconds="${2:-}"; shift 2 ;;
    --format) output_format="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "MERGE_WATCH result=usage_error reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
  esac
done

[[ -n "$mr_iid" ]] || { echo "MERGE_WATCH result=usage_error reason=missing_mr_iid" >&2; exit 64; }
[[ -n "$repo" ]] || { echo "MERGE_WATCH result=usage_error reason=missing_repo" >&2; exit 64; }
[[ -n "$project_path" ]] || { echo "MERGE_WATCH result=usage_error reason=missing_project_path" >&2; exit 64; }
[[ "$reviewed_sha" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "MERGE_WATCH result=usage_error reason=invalid_reviewed_sha" >&2; exit 64; }
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] || { echo "MERGE_WATCH result=usage_error reason=bad_timeout_seconds" >&2; exit 64; }
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "MERGE_WATCH result=usage_error reason=bad_poll_seconds" >&2; exit 64; }
case "$output_format" in human|yaml) ;; *) echo "MERGE_WATCH result=usage_error reason=bad_format" >&2; exit 64 ;; esac

command -v glab >/dev/null || { echo "MERGE_WATCH result=dependency_missing name=glab" >&2; exit 127; }
command -v node >/dev/null || { echo "MERGE_WATCH result=dependency_missing name=node" >&2; exit 127; }
[[ -f "$WRAPPERS" ]] || { echo "MERGE_WATCH result=dependency_missing name=gitlab-wrappers.sh path=$WRAPPERS" >&2; exit 127; }

reviewed_sha="$(printf '%s' "$reviewed_sha" | tr 'A-F' 'a-f')"

# Parse a single field out of the already-validated, control-char-clean
# safe_mr_json projection. Never used on a raw full MR body.
json_value() {
  local json="$1" path="$2" default_value="$3"
  JSON_PAYLOAD="$json" node - "$path" "$default_value" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
const defaultValue = process.argv[3];
let value = data;
for (const key of path) {
  if (value === null || typeof value !== 'object' || !(key in value)) {
    value = undefined;
    break;
  }
  value = value[key];
}
if (value === undefined || value === null || value === '') {
  console.log(defaultValue);
} else if (typeof value === 'object') {
  console.log(JSON.stringify(value));
} else {
  console.log(String(value));
}
NODE
}

# Best-effort merge-commit SHA for the merged terminal only. safe_mr_json does
# not project merge_commit_sha (that projection is owned elsewhere, #286), so
# read it with a control-char-guarded Node parse (never `jq`) and fall back to
# "none" if the body is unreadable. Reached only after safe_mr_json already
# proved the body clean on this poll, so a clean second read is expected.
read_merge_commit() {
  local raw status
  set +e
  raw="$(glab mr view "$mr_iid" -R "$repo" -F json 2>/dev/null)"
  status=$?
  set -e
  if [[ "$status" -ne 0 || -z "$raw" ]]; then
    printf 'none'
    return 0
  fi
  RAW_MR_JSON="$raw" node - <<'NODE'
const raw = process.env.RAW_MR_JSON || '';
if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(raw)) {
  process.stdout.write('none');
  process.exit(0);
}
let data;
try {
  data = JSON.parse(raw);
} catch (_) {
  process.stdout.write('none');
  process.exit(0);
}
const value = (data && (data.merge_commit_sha || data.squash_commit_sha)) || 'none';
process.stdout.write(String(value));
NODE
}

yaml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

g_state="none"
g_sha="none"
g_pipeline_id="none"
g_pipeline_status="none"
g_pipeline_sha="none"
g_pipeline_url="none"

emit_yaml() {
  local result="$1" reason="$2" merge_commit="$3"
  printf 'result: %s\n' "$result"
  printf 'mr: %s\n' "$(yaml_escape "$mr_iid")"
  printf 'reviewed_sha: %s\n' "$(yaml_escape "$reviewed_sha")"
  printf 'observed_sha: %s\n' "$(yaml_escape "$g_sha")"
  printf 'state: %s\n' "$(yaml_escape "$g_state")"
  printf 'pipeline_id: %s\n' "$(yaml_escape "$g_pipeline_id")"
  printf 'pipeline_status: %s\n' "$(yaml_escape "$g_pipeline_status")"
  printf 'pipeline_sha: %s\n' "$(yaml_escape "$g_pipeline_sha")"
  printf 'pipeline_url: %s\n' "$(yaml_escape "$g_pipeline_url")"
  [[ -z "$reason" || "$reason" == "none" ]] || printf 'reason: %s\n' "$(yaml_escape "$reason")"
  [[ -z "$merge_commit" || "$merge_commit" == "none" ]] || printf 'merge_commit: %s\n' "$(yaml_escape "$merge_commit")"
}

emit_result() {
  local result="$1" code="$2" message="$3" reason="${4:-}" merge_commit="${5:-}"
  if [[ "$output_format" == "yaml" ]]; then
    emit_yaml "$result" "$reason" "$merge_commit"
  else
    if [[ "$code" -eq 0 ]]; then
      echo "$message"
    else
      echo "$message" >&2
    fi
  fi
  exit "$code"
}

safe_cmd=(bash "$WRAPPERS" safe_mr_json --repo "$repo" --mr-iid "$mr_iid" --project-path "$project_path")
[[ -z "$source_branch" ]] || safe_cmd+=(--expected-source-branch "$source_branch")
[[ -z "$target_branch" ]] || safe_cmd+=(--expected-target-branch "$target_branch")

last_summary="none"
deadline=$((SECONDS + timeout_seconds))

while :; do
  set +e
  safe_out="$("${safe_cmd[@]}" 2>&1)"
  safe_status=$?
  set -e

  if [[ "$safe_status" -eq 0 ]]; then
    g_state="$(json_value "$safe_out" state none)"
    g_sha="$(json_value "$safe_out" sha none)"
    g_pipeline_id="$(json_value "$safe_out" pipeline.id none)"
    g_pipeline_status="$(json_value "$safe_out" pipeline.status none)"
    g_pipeline_sha="$(json_value "$safe_out" pipeline.sha none)"
    g_pipeline_url="$(json_value "$safe_out" pipeline.web_url none)"
    last_summary="state=$g_state sha=$g_sha pipeline=$g_pipeline_id:$g_pipeline_status:$g_pipeline_sha"
    [[ "$output_format" != "human" ]] || echo "MERGE_WATCH elapsed=${SECONDS}s $last_summary"

    # Fail closed on head drift before any success or block decision.
    if [[ "$g_sha" != "$reviewed_sha" ]]; then
      emit_result "head_changed" 2 \
        "MERGE_WATCH result=head_changed current=$g_sha reviewed=$reviewed_sha" "head_changed"
    fi

    case "$g_state" in
      merged)
        merge_commit="$(read_merge_commit)"
        emit_result "merged" 0 \
          "MERGE_WATCH result=merged mr=$mr_iid sha=$reviewed_sha merge_commit=$merge_commit" "" "$merge_commit"
        ;;
      opened)
        # A failed/canceled pipeline for the reviewed SHA means a queued
        # auto-merge will never complete: block instead of waiting out the
        # timeout. A stale pipeline (different SHA) keeps polling.
        if [[ "$g_pipeline_sha" == "$reviewed_sha" ]]; then
          case "$g_pipeline_status" in
            failed|canceled)
              emit_result "ci_failed" 1 \
                "MERGE_WATCH result=ci_failed mr=$mr_iid sha=$reviewed_sha pipeline=$g_pipeline_id status=$g_pipeline_status" "ci_failed"
              ;;
          esac
        fi
        ;;
      *)
        emit_result "unknown_mr_state" 5 \
          "MERGE_WATCH result=blocked reason=unknown_mr_state state=$g_state" "unknown_mr_state:$g_state"
        ;;
    esac
  else
    if [[ "$safe_out" == *"reason="* ]]; then
      reason="${safe_out##*reason=}"
      reason="${reason%%[[:space:]]*}"
    else
      reason=""
    fi
    case "$reason" in
      invalid_control_character:*|project_binding_mismatch|mr_iid_mismatch|source_branch_mismatch|target_branch_mismatch|invalid_sha|invalid_pipeline_sha)
        # Deterministic safe-read failure: surface immediately rather than
        # looping silently (the retro defect this helper replaces).
        emit_result "blocked" 3 "MERGE_WATCH result=blocked reason=$reason" "$reason"
        ;;
      dependency_missing_glab|dependency_missing_node)
        emit_result "dependency_missing" 127 "MERGE_WATCH result=dependency_missing reason=$reason" "$reason"
        ;;
      *)
        # Transient/not-ready safe-read failure (missing pipeline, empty/partial
        # body, transient glab error): keep polling until the timeout.
        last_summary="safe_read_retry reason=${reason:-glab_error} status=$safe_status"
        [[ "$output_format" != "human" ]] || echo "MERGE_WATCH elapsed=${SECONDS}s $last_summary"
        ;;
    esac
  fi

  [[ "$SECONDS" -lt "$deadline" ]] || break
  sleep "$poll_seconds"
done

emit_result "timeout" 4 "MERGE_WATCH result=timeout reviewed=$reviewed_sha last=$last_summary" "timeout"
