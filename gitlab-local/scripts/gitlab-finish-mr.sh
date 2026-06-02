#!/usr/bin/env bash
# Authority-aware GitLab MR finish helper.
# Convenience wrapper for gitlab-local's accepted finish-mr-authority-aware snippet.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-finish-mr.sh --mr-iid <iid> --reviewed-sha <sha> --merge-authority <authority> --caller-role <role> --source-branch <branch> --default-branch <branch> [options]

Authorities:
  approval-only | reviewer may merge | queue auto-merge | human release

Caller roles:
  builder | reviewer | authorized-parent | human

Options:
  --worktree-path <path>          Remove worktree after finish only when clean.
  --issue-iid <iid>               Report linked issue state.
  --approve-as-reviewer           Reviewer path approves before merge.
  --delete-local-source-branch    Delete local source branch after direct merge.
  --delete-remote-source-branch   Delete remote source branch after direct merge.
  --format <human|yaml>           Output format. Default: human.
  -h, --help                      Show this help.
USAGE
}

mr_iid=""
reviewed_sha=""
merge_authority=""
caller_role=""
source_branch=""
default_branch=""
worktree_path=""
issue_iid=""
approve_as_reviewer=false
delete_local_source_branch=false
delete_remote_source_branch=false
output_format="human"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr-iid)
      mr_iid="${2:-}"; shift 2 ;;
    --reviewed-sha)
      reviewed_sha="${2:-}"; shift 2 ;;
    --merge-authority)
      merge_authority="${2:-}"; shift 2 ;;
    --caller-role)
      caller_role="${2:-}"; shift 2 ;;
    --source-branch)
      source_branch="${2:-}"; shift 2 ;;
    --default-branch)
      default_branch="${2:-}"; shift 2 ;;
    --worktree-path)
      worktree_path="${2:-}"; shift 2 ;;
    --issue-iid)
      issue_iid="${2:-}"; shift 2 ;;
    --approve-as-reviewer)
      approve_as_reviewer=true; shift ;;
    --delete-local-source-branch)
      delete_local_source_branch=true; shift ;;
    --delete-remote-source-branch)
      delete_remote_source_branch=true; shift ;;
    --format)
      output_format="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "FINISH_MR result=blocked reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
  esac
done

[[ -n "$mr_iid" ]] || { echo "FINISH_MR result=blocked reason=missing_mr_iid" >&2; exit 64; }
[[ -n "$reviewed_sha" ]] || { echo "FINISH_MR result=blocked reason=missing_reviewed_sha" >&2; exit 64; }
[[ -n "$caller_role" ]] || { echo "FINISH_MR result=blocked reason=missing_caller_role" >&2; exit 4; }
[[ -n "$source_branch" ]] || { echo "FINISH_MR result=blocked reason=missing_source_branch" >&2; exit 64; }
[[ -n "$default_branch" ]] || { echo "FINISH_MR result=blocked reason=missing_default_branch" >&2; exit 64; }
[[ -n "$merge_authority" ]] || { echo "FINISH_MR result=blocked reason=missing_merge_authority" >&2; exit 4; }
case "$merge_authority" in
  approval-only|reviewer\ may\ merge|queue\ auto-merge|human\ release) ;;
  *) echo "FINISH_MR result=blocked reason=unknown_merge_authority authority=$merge_authority" >&2; exit 4 ;;
esac
case "$caller_role" in
  builder|reviewer|authorized-parent|human) ;;
  *) echo "FINISH_MR result=blocked reason=unknown_caller_role caller=$caller_role" >&2; exit 4 ;;
esac
case "$output_format" in human|yaml) ;; *) echo "FINISH_MR result=blocked reason=bad_format" >&2; exit 64 ;; esac

command -v glab >/dev/null || { echo "FINISH_MR result=blocked reason=dependency_missing name=glab" >&2; exit 127; }
command -v git >/dev/null || { echo "FINISH_MR result=blocked reason=dependency_missing name=git" >&2; exit 127; }
command -v node >/dev/null || { echo "FINISH_MR result=blocked reason=dependency_missing name=node" >&2; exit 127; }

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

yaml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

emit_yaml() {
  local result="$1" blocker="$2" action="$3" ci_guard="$4" pipeline_status="$5" pipeline_sha="$6" pipeline_url="$7" issue_state="$8" worktree_result="$9" branch_result="${10}"
  printf 'result: %s\n' "$(yaml_escape "$result")"
  [[ -z "$blocker" ]] || printf 'blocker: %s\n' "$(yaml_escape "$blocker")"
  printf 'action: %s\n' "$(yaml_escape "$action")"
  printf 'mr: %s\n' "$(yaml_escape "$mr_iid")"
  printf 'reviewed_sha: %s\n' "$(yaml_escape "$reviewed_sha")"
  printf 'ci_guard: %s\n' "$(yaml_escape "$ci_guard")"
  printf 'pipeline_status: %s\n' "$(yaml_escape "$pipeline_status")"
  printf 'pipeline_sha: %s\n' "$(yaml_escape "$pipeline_sha")"
  printf 'pipeline_url: %s\n' "$(yaml_escape "$pipeline_url")"
  printf 'issue_state: %s\n' "$(yaml_escape "$issue_state")"
  printf 'worktree: %s\n' "$(yaml_escape "$worktree_result")"
  printf 'branch: %s\n' "$(yaml_escape "$branch_result")"
}

finish_exit() {
  local code="$1" result="$2" message="$3" blocker="${4:-}" action="${5:-none}"
  local ci_guard_value="${ci_guard:-blocked}"
  local issue_state_value="${issue_state:-not_checked}"
  local worktree_value="${worktree_cleanup:-not_requested}"
  local branch_value="${branch_cleanup:-not_requested}"
  if [[ "$output_format" == "yaml" ]]; then
    emit_yaml "$result" "$blocker" "$action" "$ci_guard_value" "${pipeline_status:-none}" "${pipeline_sha:-none}" "${pipeline_url:-none}" "$issue_state_value" "$worktree_value" "$branch_value"
  else
    if [[ "$code" -eq 0 ]]; then
      echo "$message"
    else
      echo "$message" >&2
    fi
  fi
  exit "$code"
}

mr_json="$(glab mr view "$mr_iid" -F json)"
mr_state="$(json_value "$mr_json" state "")"
current_sha="$(json_value "$mr_json" sha "")"
pipeline_status="$(json_value "$mr_json" pipeline.status "none")"
pipeline_sha="$(json_value "$mr_json" pipeline.sha "none")"
pipeline_url="$(json_value "$mr_json" pipeline.web_url "none")"
ci_guard="blocked"
issue_state="not_checked"
worktree_cleanup="not_requested"
branch_cleanup="not_requested"
finish_action="none"
default_cleanup_safety="not_required"
merged_sha_candidates=("$reviewed_sha")

check_issue_state_if_requested() {
  if [[ -n "$issue_iid" && "$issue_state" == "not_checked" ]]; then
    issue_json="$(glab issue view "$issue_iid" -F json)"
    issue_state="$(json_value "$issue_json" state "unknown")"
  fi
}

add_merged_sha_candidate() {
  local candidate="$1"
  local existing
  [[ -n "$candidate" && "$candidate" != "none" ]] || return 0
  for existing in "${merged_sha_candidates[@]}"; do
    [[ "$existing" != "$candidate" ]] || return 0
  done
  merged_sha_candidates+=("$candidate")
}

refresh_merged_sha_candidates() {
  local refreshed_json merge_commit_sha squash_commit_sha
  refreshed_json="$(glab mr view "$mr_iid" -F json)" || return 0
  merge_commit_sha="$(json_value "$refreshed_json" merge_commit_sha "")"
  squash_commit_sha="$(json_value "$refreshed_json" squash_commit_sha "")"
  add_merged_sha_candidate "$merge_commit_sha"
  add_merged_sha_candidate "$squash_commit_sha"
}

establish_local_default_cleanup_safety() {
  local candidate_sha
  default_cleanup_safety="blocked_default_not_verified"
  git fetch origin
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "FINISH_MR default_update=blocked reason=dirty_checkout" >&2
    return 1
  fi
  if ! git checkout "$default_branch"; then
    echo "FINISH_MR default_update=blocked reason=checkout_failed branch=$default_branch" >&2
    return 1
  fi
  if ! git pull --ff-only origin "$default_branch"; then
    echo "FINISH_MR default_update=blocked reason=fast_forward_failed branch=$default_branch" >&2
    return 1
  fi
  for candidate_sha in "${merged_sha_candidates[@]}"; do
    if git merge-base --is-ancestor "$candidate_sha" "$default_branch"; then
      default_cleanup_safety="verified:$candidate_sha"
      return 0
    fi
  done
  echo "FINISH_MR default_update=blocked reason=merged_sha_not_on_local_default branch=$default_branch" >&2
  return 1
}

update_local_default_after_finish() {
  git fetch origin
  if [[ -z "$(git status --porcelain)" ]] && git checkout "$default_branch" && git pull --ff-only origin "$default_branch"; then
    return 0
  fi
  echo "FINISH_MR default_update=skipped reason=dirty_or_unavailable_checkout" >&2
}

if [[ "$mr_state" != "opened" ]]; then
  finish_exit 5 blocked "FINISH_MR result=blocked reason=unknown_mr_state state=${mr_state:-none}" "unknown_mr_state:${mr_state:-none}"
fi

if [[ "$current_sha" != "$reviewed_sha" ]]; then
  finish_exit 2 blocked "FINISH_MR result=blocked reason=head_changed current=${current_sha:-none} reviewed=$reviewed_sha" "head_changed"
fi

if [[ "$pipeline_sha" == "$reviewed_sha" && "$pipeline_status" == "success" ]]; then
  ci_guard="green"
elif [[ "$pipeline_sha" == "$reviewed_sha" && "$merge_authority" == "queue auto-merge" ]]; then
  case "$pipeline_status" in
    pending|running|created) ci_guard="pending_for_protected_auto_merge" ;;
  esac
fi

if [[ "$ci_guard" == "blocked" ]]; then
  reason="ci_not_green"
  if [[ "$pipeline_sha" == "none" ]]; then
    reason="missing_ci"
  elif [[ "$pipeline_sha" != "$reviewed_sha" ]]; then
    reason="stale_ci"
  fi
  finish_exit 3 blocked "FINISH_MR result=blocked reason=$reason status=$pipeline_status pipeline_sha=$pipeline_sha reviewed=$reviewed_sha" "$reason"
fi

if [[ -n "$worktree_path" ]]; then
  if [[ -n "$(git -C "$worktree_path" status --porcelain)" ]]; then
    worktree_cleanup="blocked_dirty_worktree"
    finish_exit 5 blocked "FINISH_MR result=blocked reason=dirty_worktree_cleanup worktree=$worktree_path" "dirty_worktree_cleanup"
  fi
fi

case "$caller_role:$merge_authority" in
  builder:*)
    check_issue_state_if_requested
    finish_exit 0 handoff "FINISH_MR result=handoff reason=builder_no_approve_or_merge sha=$reviewed_sha ci=$ci_guard issue_state=$issue_state worktree=$worktree_cleanup branch=$branch_cleanup" "" handoff
    ;;
  *:approval-only|*:human\ release)
    check_issue_state_if_requested
    finish_exit 0 handoff "FINISH_MR result=handoff authority=$merge_authority sha=$reviewed_sha ci=$ci_guard issue_state=$issue_state worktree=$worktree_cleanup branch=$branch_cleanup" "" handoff
    ;;
  reviewer:reviewer\ may\ merge|authorized-parent:reviewer\ may\ merge|human:reviewer\ may\ merge)
    if [[ "$approve_as_reviewer" == "true" ]]; then
      glab mr approve "$mr_iid" --sha "$reviewed_sha"
    fi
    glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false
    refresh_merged_sha_candidates
    finish_action="merged"
    ;;
  reviewer:queue\ auto-merge|authorized-parent:queue\ auto-merge|human:queue\ auto-merge)
    glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha"
    finish_action="auto_merge_queued"
    ;;
  *)
    finish_exit 4 blocked "FINISH_MR result=blocked reason=authority caller=$caller_role authority=$merge_authority" "authority"
    ;;
esac

if [[ "$finish_action" == "merged" && ( -n "$worktree_path" || "$delete_local_source_branch" == "true" ) ]]; then
  if ! establish_local_default_cleanup_safety; then
    if [[ -n "$worktree_path" ]]; then
      worktree_cleanup="blocked_default_not_verified"
    fi
    if [[ "$delete_local_source_branch" == "true" ]]; then
      branch_cleanup="local_delete_blocked_default_not_verified"
    fi
  fi
else
  update_local_default_after_finish
fi

check_issue_state_if_requested

if [[ -n "$worktree_path" && "$worktree_cleanup" != blocked_* ]]; then
  git worktree remove "$worktree_path"
  worktree_cleanup="removed"
fi

if [[ "$finish_action" == "merged" && "$delete_local_source_branch" == "true" ]]; then
  if [[ "$branch_cleanup" == "local_delete_blocked_default_not_verified" ]]; then
    :
  elif git branch -d "$source_branch"; then
    branch_cleanup="local_deleted"
  else
    branch_cleanup="local_delete_blocked"
  fi
fi
if [[ "$finish_action" == "merged" && "$delete_remote_source_branch" == "true" ]]; then
  git push origin --delete "$source_branch"
  if [[ "$branch_cleanup" == "not_requested" ]]; then
    branch_cleanup="remote_deleted"
  else
    branch_cleanup="$branch_cleanup,remote_deleted"
  fi
fi

finish_exit 0 "$finish_action" "FINISH_MR result=$finish_action sha=$reviewed_sha ci=$ci_guard pipeline_sha=$pipeline_sha pipeline_url=$pipeline_url issue_state=$issue_state worktree=$worktree_cleanup branch=$branch_cleanup" "" "$finish_action"
