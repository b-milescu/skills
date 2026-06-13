#!/usr/bin/env bash
# Read-only GitLab post-merge snapshot helper.
# Emits post_merge_snapshot.kind=post-merge-snapshot for verifier/parent routing.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-post-merge-snapshot.sh --repo <repo> --mr-iid <iid> --reviewed-sha <sha> [options]

Required:
  --repo <repo>                  GitLab repository URL accepted by glab and git.
                                 Validated up front with a read-only git ls-remote
                                 probe; a glab-only host/path form that git cannot
                                 fetch fails closed instead of degrading to an
                                 unknown-containment snapshot.
  --mr-iid <iid>                 Merge request IID to inspect.
  --reviewed-sha <sha>           SHA approved/reviewed before merge.

Options:
  --issue-iid <iid>              Linked issue/work-item IID. When omitted, derived
                                 from the authoritative GitLab closes_issues
                                 relationship, then a widened MR-description scrape.
  --default-branch <branch>      Default/target branch to inspect. Defaults to MR target_branch.
  --validation-command <command> Run a documented non-mutating post-merge validation command.
  --validation-source <source>   Documentation/source proving the validation command is non-mutating.
  -h, --help                     Show this help.

The helper is read-only with respect to GitLab and product/runtime systems: it
only reads MR/issue metadata and the MR closes_issues relationship, fetches and
inspects Git refs for containment, checks remote branch refs, and optionally runs
a caller-supplied validation command when that command has a documented
non-mutating source.
USAGE
}

fail() {
  local reason="$1" code="${2:-64}"
  echo "POST_MERGE_SNAPSHOT result=blocked reason=$reason" >&2
  exit "$code"
}

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
  process.stdout.write(defaultValue);
} else if (typeof value === 'object') {
  process.stdout.write(JSON.stringify(value));
} else {
  process.stdout.write(String(value));
}
NODE
}

# Fallback linked-issue derivation: scrape the MR description for a closing
# keyword + issue reference. Used ONLY when the authoritative closes_issues read
# below is undeterminable/unavailable; a successful closes_issues read (even an
# empty one) is authoritative and is never overridden by this scrape. Matches
# GitLab's documented closing pattern: the colon form (`Closes: #N` /
# `**Closes:** #N`), the gerund forms (closing/fixing/resolving), and tolerates
# intervening markdown emphasis (`*`, `_`) — but requires at least one
# GitLab-compatible separator (whitespace or colon) between the keyword and the
# `#N` reference, so a no-separator string like `Closes#88` / `fix#88` does not
# match.
infer_issue_iid() {
  local json="$1"
  JSON_PAYLOAD="$json" node <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const description = typeof data.description === 'string' ? data.description : '';
const match = description.match(/\b(?:clos(?:e[sd]?|ing)|fix(?:es|ed|ing)?|resolv(?:e[sd]?|ing))\b[*_:\s]*[:\s][*_:\s]*#(\d+)\b/iu);
if (match) process.stdout.write(match[1]);
NODE
}

# Authoritative linked-issue derivation: parse the GitLab closes_issues payload
# (an array of the issues the MR closes) and emit the first issue IID. Immune to
# MR description formatting and to body elision.
first_closes_issue_iid() {
  local json="$1"
  JSON_PAYLOAD="$json" node <<'NODE'
let data;
try { data = JSON.parse(process.env.JSON_PAYLOAD || '[]'); } catch (e) { process.exit(0); }
if (!Array.isArray(data)) process.exit(0);
const first = data.find((item) => item && item.iid !== undefined && item.iid !== null);
if (first) process.stdout.write(String(first.iid));
NODE
}

# Derive "<hostname> <url-encoded-project-path>" from the MR web_url so the
# authoritative closes_issues endpoint can be addressed via `glab api` without
# depending on the current working directory's git remote.
mr_project_locator() {
  local json="$1"
  JSON_PAYLOAD="$json" node <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const url = typeof data.web_url === 'string' ? data.web_url : '';
const match = url.match(/^https?:\/\/([^/]+)\/(.+?)\/-\/merge_requests\/\d+/);
if (!match) process.exit(0);
process.stdout.write(match[1] + ' ' + encodeURIComponent(match[2]));
NODE
}

json_bool_from_status() {
  case "$1" in
    true) printf 'true' ;;
    false) printf 'false' ;;
    *) printf 'null' ;;
  esac
}

contains_commit() {
  local sha="$1"
  if [[ ! "$sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf 'not_applicable'
    return 0
  fi
  if [[ "$default_branch_fetch_status" != "fetched" || ! "$target_observed_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf 'unknown'
    return 0
  fi
  set +e
  git merge-base --is-ancestor "$sha" "$target_observed_sha"
  local status=$?
  set -e
  case "$status" in
    0) printf 'true' ;;
    1) printf 'false' ;;
    *) printf 'unknown' ;;
  esac
}

repo=""
mr_iid=""
reviewed_sha=""
issue_iid=""
default_branch=""
validation_command=""
validation_source=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --mr-iid) mr_iid="${2:-}"; shift 2 ;;
    --reviewed-sha) reviewed_sha="${2:-}"; shift 2 ;;
    --issue-iid) issue_iid="${2:-}"; shift 2 ;;
    --default-branch) default_branch="${2:-}"; shift 2 ;;
    --validation-command) validation_command="${2:-}"; shift 2 ;;
    --validation-source) validation_source="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown_arg:$1" ;;
  esac
done

[[ -n "$repo" ]] || fail missing_repo
[[ -n "$mr_iid" ]] || fail missing_mr_iid
[[ "$reviewed_sha" =~ ^[0-9a-fA-F]{40}$ ]] || fail invalid_reviewed_sha
command -v glab >/dev/null || fail dependency_missing_glab 127
command -v git >/dev/null || fail dependency_missing_git 127
command -v node >/dev/null || fail dependency_missing_node 127

reviewed_sha="$(node -e 'process.stdout.write(process.argv[1].toLowerCase())' "$reviewed_sha")"

# The --help contract requires --repo be accepted by both glab and git, but glab
# tolerates host/path forms (e.g. gitlab.example.com/group/project) that git cannot
# fetch. Probe git-fetchability up front so a non-git-fetchable --repo fails closed
# with a clear diagnostic instead of silently degrading to an unknown-containment
# snapshot. Read-only: ls-remote only inspects remote refs.
set +e
git ls-remote --quiet "$repo" HEAD >/dev/null 2>&1
repo_fetchable_status=$?
set -e
[[ "$repo_fetchable_status" -eq 0 ]] || fail "repo_not_git_fetchable:$repo"

mr_json="$(glab mr view "$mr_iid" -R "$repo" -F json)"
mr_state="$(json_value "$mr_json" state unknown)"
mr_url="$(json_value "$mr_json" web_url "")"
source_branch="$(json_value "$mr_json" source_branch "")"
target_branch="$(json_value "$mr_json" target_branch "")"
mr_head_sha="$(json_value "$mr_json" sha "")"
merge_commit_sha="$(json_value "$mr_json" merge_commit_sha "")"
squash_commit_sha="$(json_value "$mr_json" squash_commit_sha "")"
should_remove_source_branch="$(json_value "$mr_json" should_remove_source_branch unknown)"
force_remove_source_branch="$(json_value "$mr_json" force_remove_source_branch unknown)"
remove_source_branch="$(json_value "$mr_json" remove_source_branch unknown)"
[[ -n "$default_branch" ]] || default_branch="$target_branch"
# Resolve the linked issue when no explicit --issue-iid override was given.
# Primary + authoritative: the GitLab closes_issues relationship. A successful
# read is authoritative even when empty (the MR closes no issue => true
# not_linked); GitLab returns the closed issue for merged MRs too, so a
# successful-empty read is NOT second-guessed by the description.
# Fallback: the widened MR-description scrape runs ONLY when the closes_issues
# read is undeterminable/unavailable (locator underivable or the API errored).
# A read that resolves nothing and could not be determined is reported below as
# link_undeterminable, distinct from a true not_linked. Read-only (GET).
link_determinable="true"
if [[ -z "$issue_iid" ]]; then
  locator="$(mr_project_locator "$mr_json")"
  project_host="${locator%% *}"
  project_path_enc="${locator##* }"
  closes_issues_determinable="false"
  if [[ -n "$locator" && -n "$project_host" && -n "$project_path_enc" ]]; then
    set +e
    closes_json="$(glab api --hostname "$project_host" "projects/${project_path_enc}/merge_requests/${mr_iid}/closes_issues" 2>/dev/null)"
    closes_status=$?
    set -e
    if [[ "$closes_status" -eq 0 ]]; then
      closes_issues_determinable="true"
      issue_iid="$(first_closes_issue_iid "$closes_json")"
    fi
  fi
  if [[ -z "$issue_iid" && "$closes_issues_determinable" != "true" ]]; then
    # closes_issues was undeterminable/unavailable: fall back to the widened
    # description scrape. A successful-but-empty closes_issues read is left as an
    # authoritative not_linked and is never overridden here.
    issue_iid="$(infer_issue_iid "$mr_json")"
    [[ -n "$issue_iid" ]] || link_determinable="false"
  fi
fi

target_observed_sha=""
default_branch_fetch_status="not-run"
set +e
git fetch --quiet "$repo" "$default_branch"
fetch_status=$?
set -e
if [[ "$fetch_status" -eq 0 ]]; then
  default_branch_fetch_status="fetched"
  set +e
  target_observed_sha="$(git rev-parse FETCH_HEAD)"
  rev_parse_status=$?
  set -e
  if [[ "$rev_parse_status" -ne 0 || ! "$target_observed_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    target_observed_sha=""
    default_branch_fetch_status="unknown"
  fi
else
  default_branch_fetch_status="failed"
fi

contains_reviewed_status="$(contains_commit "$reviewed_sha")"
contains_merge_status="$(contains_commit "$merge_commit_sha")"
contains_squash_status="$(contains_commit "$squash_commit_sha")"
contains_reviewed_json="$(json_bool_from_status "$contains_reviewed_status")"
contains_merge_json="$(json_bool_from_status "$contains_merge_status")"
contains_squash_json="$(json_bool_from_status "$contains_squash_status")"

satisfied_by="none"
if [[ "$contains_reviewed_status" == "true" ]]; then
  satisfied_by="reviewed_sha"
elif [[ "$contains_merge_status" == "true" ]]; then
  satisfied_by="merge_commit_sha"
elif [[ "$contains_squash_status" == "true" ]]; then
  satisfied_by="squash_commit_sha"
elif [[ "$contains_reviewed_status" == "unknown" || "$contains_merge_status" == "unknown" || "$contains_squash_status" == "unknown" ]]; then
  satisfied_by="unknown"
fi

issue_state="not_checked"
issue_url=""
closure_status="not_linked"
if [[ -n "$issue_iid" ]]; then
  set +e
  issue_json="$(glab issue view "$issue_iid" -R "$repo" -F json)"
  issue_status=$?
  set -e
  if [[ "$issue_status" -eq 0 ]]; then
    issue_state="$(json_value "$issue_json" state unknown)"
    issue_url="$(json_value "$issue_json" web_url "")"
    case "$issue_state" in
      closed|closed_state) closure_status="closed" ;;
      opened|open)
        if [[ "$mr_state" == "merged" ]]; then
          closure_status="issue_closure_pending"
        else
          closure_status="open"
        fi
        ;;
      *) closure_status="unknown" ;;
    esac
  else
    issue_state="unknown"
    closure_status="unknown"
  fi
elif [[ "$link_determinable" != "true" ]]; then
  closure_status="link_undeterminable"
fi

source_branch_exists="unknown"
source_branch_ref_sha=""
if [[ -n "$source_branch" ]]; then
  set +e
  source_ref_output="$(git ls-remote "$repo" "refs/heads/$source_branch")"
  source_ref_status=$?
  set -e
  if [[ "$source_ref_status" -eq 0 ]]; then
    if [[ -n "$source_ref_output" ]]; then
      source_branch_exists="true"
      source_branch_ref_sha="${source_ref_output%%[[:space:]]*}"
    else
      source_branch_exists="false"
    fi
  fi
fi

source_branch_policy="unknown"
case "$force_remove_source_branch:$should_remove_source_branch:$remove_source_branch" in
  *true*) source_branch_policy="delete_requested" ;;
  *false*) source_branch_policy="retain_requested" ;;
esac
source_branch_cleanup_status="unknown"
case "$source_branch_exists:$source_branch_policy" in
  false:*) source_branch_cleanup_status="cleaned_up" ;;
  true:delete_requested) source_branch_cleanup_status="source_branch_cleanup_pending" ;;
  true:*) source_branch_cleanup_status="source_branch_retained_by_policy_or_unknown" ;;
esac

validation_status="not-run"
validation_not_run_reason="not-documented"
validation_exit_code=""
if [[ -n "$validation_command" ]]; then
  if [[ -z "$validation_source" ]]; then
    validation_not_run_reason="missing-validation-source"
  else
    validation_log="$(mktemp "${TMPDIR:-/tmp}/post-merge-validation.XXXXXX")"
    set +e
    bash -lc "$validation_command" >"$validation_log" 2>&1
    validation_exit_code=$?
    set -e
    rm -f "$validation_log"
    validation_not_run_reason="N/A"
    if [[ "$validation_exit_code" -eq 0 ]]; then
      validation_status="pass"
    else
      validation_status="fail"
    fi
  fi
fi

export SNAPSHOT_REPO="$repo"
export SNAPSHOT_MR_IID="$mr_iid"
export SNAPSHOT_MR_STATE="$mr_state"
export SNAPSHOT_MR_URL="$mr_url"
export SNAPSHOT_REVIEWED_SHA="$reviewed_sha"
export SNAPSHOT_MR_HEAD_SHA="$mr_head_sha"
export SNAPSHOT_MERGE_COMMIT_SHA="$merge_commit_sha"
export SNAPSHOT_SQUASH_COMMIT_SHA="$squash_commit_sha"
export SNAPSHOT_SOURCE_BRANCH="$source_branch"
export SNAPSHOT_TARGET_BRANCH="$target_branch"
export SNAPSHOT_DEFAULT_BRANCH="$default_branch"
export SNAPSHOT_TARGET_OBSERVED_SHA="$target_observed_sha"
export SNAPSHOT_DEFAULT_FETCH_STATUS="$default_branch_fetch_status"
export SNAPSHOT_CONTAINS_REVIEWED_STATUS="$contains_reviewed_status"
export SNAPSHOT_CONTAINS_MERGE_STATUS="$contains_merge_status"
export SNAPSHOT_CONTAINS_SQUASH_STATUS="$contains_squash_status"
export SNAPSHOT_CONTAINS_REVIEWED_JSON="$contains_reviewed_json"
export SNAPSHOT_CONTAINS_MERGE_JSON="$contains_merge_json"
export SNAPSHOT_CONTAINS_SQUASH_JSON="$contains_squash_json"
export SNAPSHOT_SATISFIED_BY="$satisfied_by"
export SNAPSHOT_ISSUE_IID="$issue_iid"
export SNAPSHOT_ISSUE_STATE="$issue_state"
export SNAPSHOT_ISSUE_URL="$issue_url"
export SNAPSHOT_CLOSURE_STATUS="$closure_status"
export SNAPSHOT_SOURCE_EXISTS="$source_branch_exists"
export SNAPSHOT_SOURCE_REF_SHA="$source_branch_ref_sha"
export SNAPSHOT_SOURCE_POLICY="$source_branch_policy"
export SNAPSHOT_SOURCE_CLEANUP_STATUS="$source_branch_cleanup_status"
export SNAPSHOT_VALIDATION_COMMAND="$validation_command"
export SNAPSHOT_VALIDATION_SOURCE="$validation_source"
export SNAPSHOT_VALIDATION_STATUS="$validation_status"
export SNAPSHOT_VALIDATION_NOT_RUN_REASON="$validation_not_run_reason"
export SNAPSHOT_VALIDATION_EXIT_CODE="$validation_exit_code"

node <<'NODE'
function nullable(value) {
  return value === undefined || value === null || value === '' ? null : value;
}
function boolFromEnv(name) {
  const value = process.env[name];
  if (value === 'true') return true;
  if (value === 'false') return false;
  return null;
}
const pending = [];
const mrState = process.env.SNAPSHOT_MR_STATE || 'unknown';
const closureStatus = process.env.SNAPSHOT_CLOSURE_STATUS || 'unknown';
const cleanupStatus = process.env.SNAPSHOT_SOURCE_CLEANUP_STATUS || 'unknown';
const validationStatus = process.env.SNAPSHOT_VALIDATION_STATUS || 'not-run';
const satisfiedBy = process.env.SNAPSHOT_SATISFIED_BY || 'none';
const fetchStatus = process.env.SNAPSHOT_DEFAULT_FETCH_STATUS || 'unknown';
if (mrState !== 'merged') pending.push('mr_not_merged');
if (fetchStatus !== 'fetched' || satisfiedBy === 'unknown') pending.push('default_branch_containment_unknown');
if (mrState === 'merged' && satisfiedBy === 'none') pending.push('default_branch_containment_missing');
if (closureStatus === 'issue_closure_pending') pending.push('issue_closure_pending');
if (closureStatus === 'link_undeterminable') pending.push('linked_issue_undeterminable');
if (cleanupStatus === 'source_branch_cleanup_pending') pending.push('source_branch_cleanup_pending');
if (cleanupStatus === 'source_branch_retained_by_policy_or_unknown') pending.push('source_branch_retained_by_policy_or_unknown');
if (validationStatus === 'not-run') pending.push('post_merge_validation_not_run');
if (validationStatus === 'fail') pending.push('post_merge_validation_failed');
const snapshot = {
  post_merge_snapshot: {
    kind: 'post-merge-snapshot',
    version: '1',
    repo: process.env.SNAPSHOT_REPO,
    mr: {
      iid: process.env.SNAPSHOT_MR_IID,
      state: mrState,
      url: nullable(process.env.SNAPSHOT_MR_URL),
      reviewed_sha: process.env.SNAPSHOT_REVIEWED_SHA,
      head_sha: nullable(process.env.SNAPSHOT_MR_HEAD_SHA),
      merge_commit_sha: nullable(process.env.SNAPSHOT_MERGE_COMMIT_SHA),
      squash_commit_sha: nullable(process.env.SNAPSHOT_SQUASH_COMMIT_SHA),
      source_branch: nullable(process.env.SNAPSHOT_SOURCE_BRANCH),
      target_branch: nullable(process.env.SNAPSHOT_TARGET_BRANCH),
    },
    default_branch: {
      name: nullable(process.env.SNAPSHOT_DEFAULT_BRANCH),
      observed_sha: nullable(process.env.SNAPSHOT_TARGET_OBSERVED_SHA),
      fetch_status: fetchStatus,
      contains_reviewed_sha: boolFromEnv('SNAPSHOT_CONTAINS_REVIEWED_JSON'),
      contains_reviewed_sha_status: process.env.SNAPSHOT_CONTAINS_REVIEWED_STATUS,
      contains_merge_commit_sha: boolFromEnv('SNAPSHOT_CONTAINS_MERGE_JSON'),
      contains_merge_commit_sha_status: process.env.SNAPSHOT_CONTAINS_MERGE_STATUS,
      contains_squash_commit_sha: boolFromEnv('SNAPSHOT_CONTAINS_SQUASH_JSON'),
      contains_squash_commit_sha_status: process.env.SNAPSHOT_CONTAINS_SQUASH_STATUS,
      containment_satisfied_by: satisfiedBy,
    },
    linked_issue: {
      iid: nullable(process.env.SNAPSHOT_ISSUE_IID),
      state: process.env.SNAPSHOT_ISSUE_STATE || 'not_checked',
      url: nullable(process.env.SNAPSHOT_ISSUE_URL),
      closure_status: closureStatus,
    },
    source_branch_cleanup: {
      source_branch: nullable(process.env.SNAPSHOT_SOURCE_BRANCH),
      remote_ref_exists: process.env.SNAPSHOT_SOURCE_EXISTS || 'unknown',
      remote_ref_sha: nullable(process.env.SNAPSHOT_SOURCE_REF_SHA),
      policy: process.env.SNAPSHOT_SOURCE_POLICY || 'unknown',
      status: cleanupStatus,
    },
    validation: {
      command: nullable(process.env.SNAPSHOT_VALIDATION_COMMAND),
      source: nullable(process.env.SNAPSHOT_VALIDATION_SOURCE),
      status: validationStatus,
      not_run_reason: process.env.SNAPSHOT_VALIDATION_NOT_RUN_REASON || 'N/A',
      exit_code: nullable(process.env.SNAPSHOT_VALIDATION_EXIT_CODE),
    },
    pending_items: [...new Set(pending)],
  },
};
process.stdout.write(JSON.stringify(snapshot, null, 2));
process.stdout.write('\n');
NODE
