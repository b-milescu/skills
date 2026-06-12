#!/usr/bin/env bash
# SHA-pinned GitLab CI watcher helper.
# Convenience wrapper for gitlab's accepted ci-watch-sha-pinned snippet.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-ci-watch.sh --mr-iid <iid> --source-branch <branch> --reviewed-sha <sha> [options]

Options:
  --timeout-seconds <seconds>  Max wait time. Default: 900.
  --poll-seconds <seconds>     Poll interval. Default: 15.
  --format <human|yaml>        Output format. Default: human.
  -h, --help                   Show this help.
USAGE
}

mr_iid=""
source_branch=""
reviewed_sha=""
timeout_seconds=900
poll_seconds=15
output_format="human"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr-iid)
      mr_iid="${2:-}"; shift 2 ;;
    --source-branch)
      source_branch="${2:-}"; shift 2 ;;
    --reviewed-sha)
      reviewed_sha="${2:-}"; shift 2 ;;
    --timeout-seconds)
      timeout_seconds="${2:-}"; shift 2 ;;
    --poll-seconds)
      poll_seconds="${2:-}"; shift 2 ;;
    --format)
      output_format="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "CI_WATCH result=usage_error reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
  esac
done

[[ -n "$mr_iid" ]] || { echo "CI_WATCH result=usage_error reason=missing_mr_iid" >&2; exit 64; }
[[ -n "$source_branch" ]] || { echo "CI_WATCH result=usage_error reason=missing_source_branch" >&2; exit 64; }
[[ -n "$reviewed_sha" ]] || { echo "CI_WATCH result=usage_error reason=missing_reviewed_sha" >&2; exit 64; }
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] || { echo "CI_WATCH result=usage_error reason=bad_timeout_seconds" >&2; exit 64; }
[[ "$poll_seconds" =~ ^[0-9]+$ ]] || { echo "CI_WATCH result=usage_error reason=bad_poll_seconds" >&2; exit 64; }
case "$output_format" in human|yaml) ;; *) echo "CI_WATCH result=usage_error reason=bad_format" >&2; exit 64 ;; esac

command -v glab >/dev/null || { echo "CI_WATCH result=dependency_missing name=glab" >&2; exit 127; }
command -v node >/dev/null || { echo "CI_WATCH result=dependency_missing name=node" >&2; exit 127; }

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

json_failed_jobs() {
  local json="$1"
  JSON_PAYLOAD="$json" node - <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const failed = (Array.isArray(data.jobs) ? data.jobs : [])
  .filter((job) => job.allow_failure !== true && ['failed', 'canceled', 'skipped'].includes(job.status))
  .map((job) => job.name)
  .filter(Boolean);
process.stdout.write(failed.join(','));
NODE
}

yaml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

emit_yaml() {
  local result="$1" observed_sha="$2" pipeline_id="$3" status="$4" url="$5" failed_jobs="$6" blocker="${7:-}" merge_commit="${8:-}"
  printf 'result: %s\n' "$result"
  printf 'mr: %s\n' "$(yaml_escape "$mr_iid")"
  printf 'expected_sha: %s\n' "$(yaml_escape "$reviewed_sha")"
  printf 'observed_sha: %s\n' "$(yaml_escape "$observed_sha")"
  printf 'pipeline_id: %s\n' "$(yaml_escape "$pipeline_id")"
  printf 'status: %s\n' "$(yaml_escape "$status")"
  printf 'url: %s\n' "$(yaml_escape "$url")"
  printf 'failed_jobs: %s\n' "$(yaml_escape "${failed_jobs:-none}")"
  [[ -z "$blocker" ]] || printf 'blocker: %s\n' "$(yaml_escape "$blocker")"
  [[ -z "$merge_commit" || "$merge_commit" == "none" ]] || printf 'merge_commit: %s\n' "$(yaml_escape "$merge_commit")"
}

emit_result() {
  local result="$1" observed_sha="$2" pipeline_id="$3" status="$4" url="$5" failed_jobs="$6" message="$7" code="$8" blocker="${9:-}" merge_commit="${10:-}"
  if [[ "$output_format" == "yaml" ]]; then
    emit_yaml "$result" "$observed_sha" "$pipeline_id" "$status" "$url" "$failed_jobs" "$blocker" "$merge_commit"
  else
    if [[ "$code" -eq 0 ]]; then
      echo "$message"
    else
      echo "$message" >&2
    fi
  fi
  exit "$code"
}

pipeline_id="none"
pipeline_status="none"
pipeline_sha="none"
pipeline_url="none"
current_sha="none"
failed_jobs="none"
deadline=$((SECONDS + timeout_seconds))

while :; do
  mr_json="$(glab mr view "$mr_iid" -F json)"
  mr_state="$(json_value "$mr_json" state "")"
  current_sha="$(json_value "$mr_json" sha "")"

  if [[ "$mr_state" == "merged" ]]; then
    # Fail closed before claiming success: a merge whose observed head is not the
    # reviewed SHA merged an unreviewed commit, so it is head_changed, not merged.
    if [[ "$current_sha" != "$reviewed_sha" ]]; then
      emit_result "head_changed" "${current_sha:-none}" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
        "CI_WATCH result=head_changed current=${current_sha:-none} reviewed=$reviewed_sha" 2 "head_changed"
    fi
    merge_commit="$(json_value "$mr_json" merge_commit_sha "none")"
    if [[ "$merge_commit" == "none" ]]; then
      merge_commit="$(json_value "$mr_json" squash_commit_sha "none")"
    fi
    emit_result "merged" "${current_sha:-none}" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
      "CI_WATCH result=merged mr=$mr_iid merge_commit=$merge_commit" 0 "" "$merge_commit"
  fi

  if [[ "$mr_state" != "opened" ]]; then
    emit_result "unknown_mr_state" "${current_sha:-none}" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
      "CI_WATCH result=blocked reason=unknown_mr_state state=${mr_state:-none}" 5 "unknown_mr_state:${mr_state:-none}"
  fi

  if [[ "$current_sha" != "$reviewed_sha" ]]; then
    emit_result "head_changed" "${current_sha:-none}" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
      "CI_WATCH result=head_changed current=${current_sha:-none} reviewed=$reviewed_sha" 2 "head_changed"
  fi

  pipeline_id="$(json_value "$mr_json" pipeline.id "none")"
  pipeline_status="$(json_value "$mr_json" pipeline.status "none")"
  pipeline_sha="$(json_value "$mr_json" pipeline.sha "none")"
  pipeline_url="$(json_value "$mr_json" pipeline.web_url "none")"

  branch_json="$(glab ci status --branch "$source_branch" -F json 2>/dev/null || true)"
  branch_input="$branch_json"
  [[ -n "$branch_input" ]] || branch_input='{}'
  branch_id="$(json_value "$branch_input" pipeline.id "none" 2>/dev/null || echo none)"
  branch_status="$(json_value "$branch_input" pipeline.status "none" 2>/dev/null || echo none)"
  branch_sha="$(json_value "$branch_input" pipeline.sha "none" 2>/dev/null || echo none)"
  failed_jobs="$(json_failed_jobs "$branch_input" 2>/dev/null || true)"
  failed_jobs="${failed_jobs:-none}"
  last_summary="mr_pipeline=$pipeline_id:$pipeline_status:$pipeline_sha branch_pipeline=$branch_id:$branch_status:$branch_sha failed_jobs=$failed_jobs"
  [[ "$output_format" != "human" ]] || echo "CI_WATCH elapsed=${SECONDS}s $last_summary"

  if [[ "$branch_sha" == "$reviewed_sha" && "$failed_jobs" != "none" ]]; then
    emit_result "fail" "$current_sha" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
      "CI_WATCH result=fail pipeline=$pipeline_id status=$pipeline_status sha=$pipeline_sha failed_jobs=$failed_jobs" 1 "required_job_failed"
  fi

  if [[ "$pipeline_sha" == "$reviewed_sha" ]]; then
    case "$pipeline_status" in
      success)
        emit_result "pass" "$current_sha" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
          "CI_WATCH result=pass pipeline=$pipeline_id sha=$pipeline_sha url=$pipeline_url" 0
        ;;
      failed|canceled|skipped)
        emit_result "fail" "$current_sha" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
          "CI_WATCH result=fail pipeline=$pipeline_id status=$pipeline_status sha=$pipeline_sha failed_jobs=$failed_jobs" 1 "ci_red"
        ;;
    esac
  fi

  [[ "$SECONDS" -lt "$deadline" ]] || break
  sleep "$poll_seconds"
done

final_result="timeout"
if [[ "$pipeline_sha" != "none" && "$pipeline_sha" != "$reviewed_sha" ]]; then
  final_result="stale_ci"
fi
emit_result "$final_result" "$current_sha" "$pipeline_id" "$pipeline_status" "$pipeline_url" "$failed_jobs" \
  "CI_WATCH result=$final_result reviewed=$reviewed_sha last=$last_summary" 3 "$final_result"
