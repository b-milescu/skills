#!/usr/bin/env bash
# Thin fail-closed fallback wrappers for GitLab Mutation Guard body/metadata snippets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  cat <<'USAGE'
Usage: gitlab-wrappers.sh <wrapper> [options]

Wrappers:
  draft_mr_create           Create a Draft MR from --description-file.
  mr_description_update     Update an MR description from --description-file.
  issue_note_create          Post an issue note from --message-file.
  mr_note_create             Post an MR note from --message-file.
  label_reconcile            Add/remove issue labels without replacement assumptions.
  safe_mr_json               Emit validated decision-grade MR metadata JSON.
  auto_merge_api_fallback    Queue auto-merge, falling back to the API for known 405s.

Run gitlab-local help-first checks for the underlying glab commands before use.
USAGE
}

fail() {
  local prefix="$1" code="$2" reason="$3"
  echo "$prefix result=blocked reason=$reason" >&2
  exit "$code"
}

require_glab() {
  command -v glab >/dev/null || fail GITLAB_WRAPPER 127 dependency_missing_glab
}

require_node() {
  command -v node >/dev/null || fail GITLAB_WRAPPER 127 dependency_missing_node
}

content_guard_path() {
  local prefix="$1" guard="${GITLAB_CONTENT_GUARD:-$SCRIPT_DIR/gitlab-content-guard.sh}"
  [[ -n "$guard" && -x "$guard" ]] || fail "$prefix" 127 dependency_missing_content_guard
  printf '%s' "$guard"
}

require_file_arg() {
  local prefix="$1" file="$2"
  [[ -n "$file" ]] || fail "$prefix" 64 missing_message_file
  [[ -f "$file" && -r "$file" ]] || fail "$prefix" 66 unreadable_message_file
  [[ -s "$file" ]] || fail "$prefix" 64 empty_message_file
}

validate_text_file() {
  local prefix="$1" file="$2" label="$3" guard result status reason
  guard="$(content_guard_path "$prefix")"
  set +e
  result="$("$guard" --file "$file" --role "$label" 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] && return 0

  reason="${result#*reason=}"
  if [[ "$reason" == "$result" || -z "$reason" ]]; then
    reason=content_guard_failed
  fi
  reason="${reason%%$'\n'*}"
  reason="${reason%%$'\r'*}"
  fail "$prefix" "$status" "$reason"
}

derive_gitlab_hostname() {
  local prefix="$1" repo="$2" explicit_hostname="${3:-}" result status
  require_node
  set +e
  result="$(node - "$repo" "$explicit_hostname" <<'NODE'
const repo = process.argv[2] || '';
const explicit = process.argv[3] || '';

function reject(reason) {
  process.stdout.write(reason);
  process.exit(2);
}

function isValidHost(host) {
  return typeof host === 'string' && host.length > 0 && !/[\u0000-\u001F\u007F\s/@]/u.test(host);
}

let derived = '';
try {
  if (/^[a-z][a-z0-9+.-]*:\/\//iu.test(repo)) {
    derived = new URL(repo).host;
  } else {
    const scpLike = repo.match(/^[^@\s]+@([^:\s/]+(?::[0-9]+)?):.+$/u);
    if (scpLike) derived = scpLike[1];
  }
} catch (_) {
  reject('invalid_repo_url');
}

if (derived && !isValidHost(derived)) reject('invalid_repo_host');
if (explicit && !isValidHost(explicit)) reject('invalid_api_hostname');
if (derived && explicit && derived.toLowerCase() !== explicit.toLowerCase()) reject('api_hostname_repo_mismatch');

const host = derived || explicit;
if (!host) reject('missing_api_hostname');
process.stdout.write(host);
NODE
)"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "$prefix" 64 "${result:-invalid_api_hostname}"
  printf '%s' "$result"
}

json_field() {
  local json="$1" path="$2"
  JSON_PAYLOAD="$json" node - "$path" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
let value = data;
for (const key of path) value = value?.[key];
if (value === undefined || value === null) process.exit(1);
if (typeof value === 'object') {
  process.stdout.write(JSON.stringify(value));
} else {
  process.stdout.write(String(value));
}
NODE
}

safe_mr_json_from_raw() {
  local raw_json="$1" mr_iid="$2" project_path="$3" expected_source="$4" expected_target="$5"
  RAW_MR_JSON="$raw_json" node - "$mr_iid" "$project_path" "$expected_source" "$expected_target" <<'NODE'
const raw = process.env.RAW_MR_JSON || '';
const mrIid = process.argv[2];
const projectPath = process.argv[3];
const expectedSource = process.argv[4];
const expectedTarget = process.argv[5];

function fail(reason) {
  console.error(`SAFE_MR_JSON result=blocked reason=${reason}`);
  process.exit(2);
}
function hasInvalidControl(value) {
  return /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(value);
}
function requireString(value, name) {
  if (typeof value !== 'string' || value.length === 0) fail(`missing_${name}`);
  if (hasInvalidControl(value)) fail(`invalid_control_character:${name}`);
  return value;
}
function requireSha(value, name) {
  const sha = requireString(value, name);
  if (!/^[0-9a-f]{40}$/i.test(sha)) fail(`invalid_${name}`);
  return sha.toLowerCase();
}
function requireNumber(value, name) {
  if (typeof value !== 'number' || !Number.isFinite(value)) fail(`missing_${name}`);
  return value;
}

if (!raw) fail('empty_mr_json');
if (hasInvalidControl(raw)) fail('invalid_control_character:raw_json');
let data;
try {
  data = JSON.parse(raw);
} catch (_) {
  fail('invalid_json');
}
if (!data || typeof data !== 'object' || Array.isArray(data)) fail('invalid_json_root');
if (String(data.iid ?? '') !== mrIid) fail('mr_iid_mismatch');
const referencesFull = requireString(data.references?.full, 'references_full');
if (referencesFull !== `${projectPath}!${mrIid}`) fail('project_binding_mismatch');
const sourceBranch = requireString(data.source_branch, 'source_branch');
const targetBranch = requireString(data.target_branch, 'target_branch');
if (expectedSource && sourceBranch !== expectedSource) fail('source_branch_mismatch');
if (expectedTarget && targetBranch !== expectedTarget) fail('target_branch_mismatch');
const pipeline = data.pipeline;
if (!pipeline || typeof pipeline !== 'object' || Array.isArray(pipeline)) fail('missing_pipeline');
const out = {
  iid: Number(data.iid),
  project_path: projectPath,
  project_id: requireNumber(data.project_id, 'project_id'),
  source_project_id: requireNumber(data.source_project_id, 'source_project_id'),
  target_project_id: requireNumber(data.target_project_id, 'target_project_id'),
  state: requireString(data.state, 'state'),
  draft: Boolean(data.draft),
  source_branch: sourceBranch,
  target_branch: targetBranch,
  sha: requireSha(data.sha, 'sha'),
  pipeline: {
    id: pipeline.id == null ? fail('missing_pipeline_id') : String(pipeline.id),
    status: requireString(pipeline.status, 'pipeline_status'),
    sha: requireSha(pipeline.sha, 'pipeline_sha'),
    web_url: requireString(pipeline.web_url, 'pipeline_web_url'),
  },
  detailed_merge_status: requireString(data.detailed_merge_status, 'detailed_merge_status'),
  web_url: requireString(data.web_url, 'web_url'),
};
process.stdout.write(JSON.stringify(out));
NODE
}

draft_mr_create() {
  local repo="" target_branch="" source_branch="" title="" description_file="" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --target-branch) target_branch="${2:-}"; shift 2 ;;
      --source-branch) source_branch="${2:-}"; shift 2 ;;
      --title) title="${2:-}"; shift 2 ;;
      --description-file) description_file="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail DRAFT_MR_CREATE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail DRAFT_MR_CREATE 64 missing_repo
  [[ -n "$target_branch" ]] || fail DRAFT_MR_CREATE 64 missing_target_branch
  [[ -n "$source_branch" ]] || fail DRAFT_MR_CREATE 64 missing_source_branch
  [[ -n "$title" ]] || fail DRAFT_MR_CREATE 64 missing_title
  require_file_arg DRAFT_MR_CREATE "$description_file"
  validate_text_file DRAFT_MR_CREATE "$description_file" description_file
  require_glab
  description="$(<"$description_file")"
  glab mr create -R "$repo" --draft --push --target-branch "$target_branch" --source-branch "$source_branch" \
    --title "$title" --description "$description" --yes
  echo "DRAFT_MR_CREATE result=created source_branch=$source_branch target_branch=$target_branch repo=$repo"
}

mr_description_update() {
  local repo="" mr_iid="" description_file="" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --mr-iid) mr_iid="${2:-}"; shift 2 ;;
      --description-file) description_file="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail MR_DESCRIPTION_UPDATE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail MR_DESCRIPTION_UPDATE 64 missing_repo
  [[ -n "$mr_iid" ]] || fail MR_DESCRIPTION_UPDATE 64 missing_mr_iid
  require_file_arg MR_DESCRIPTION_UPDATE "$description_file"
  validate_text_file MR_DESCRIPTION_UPDATE "$description_file" description_file
  require_glab
  description="$(<"$description_file")"
  glab mr update "$mr_iid" -R "$repo" --description "$description"
  echo "MR_DESCRIPTION_UPDATE result=updated mr=$mr_iid repo=$repo"
}

issue_note_create() {
  local repo="" issue_iid="" message_file="" message=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --issue-iid) issue_iid="${2:-}"; shift 2 ;;
      --message-file) message_file="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail ISSUE_NOTE_CREATE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail ISSUE_NOTE_CREATE 64 missing_repo
  [[ -n "$issue_iid" ]] || fail ISSUE_NOTE_CREATE 64 missing_issue_iid
  require_file_arg ISSUE_NOTE_CREATE "$message_file"
  validate_text_file ISSUE_NOTE_CREATE "$message_file" message_file
  require_glab
  message="$(<"$message_file")"
  glab issue note "$issue_iid" -R "$repo" --message "$message"
  echo "ISSUE_NOTE_CREATE result=created issue=$issue_iid repo=$repo"
}

mr_note_create() {
  local repo="" mr_iid="" message_file="" message=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --mr-iid) mr_iid="${2:-}"; shift 2 ;;
      --message-file) message_file="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail MR_NOTE_CREATE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail MR_NOTE_CREATE 64 missing_repo
  [[ -n "$mr_iid" ]] || fail MR_NOTE_CREATE 64 missing_mr_iid
  require_file_arg MR_NOTE_CREATE "$message_file"
  validate_text_file MR_NOTE_CREATE "$message_file" message_file
  require_glab
  message="$(<"$message_file")"
  glab mr note create "$mr_iid" -R "$repo" --message "$message"
  echo "MR_NOTE_CREATE result=created mr=$mr_iid repo=$repo"
}

label_reconcile() {
  local repo="" issue_iid="" add_labels="" remove_labels="" state_labels="" category_labels=""
  local issue_json plan add_csv remove_csv final_csv
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --issue-iid) issue_iid="${2:-}"; shift 2 ;;
      --add-labels) add_labels="${2:-}"; shift 2 ;;
      --remove-labels) remove_labels="${2:-}"; shift 2 ;;
      --state-labels) state_labels="${2:-}"; shift 2 ;;
      --category-labels) category_labels="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail LABEL_RECONCILE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail LABEL_RECONCILE 64 missing_repo
  [[ -n "$issue_iid" ]] || fail LABEL_RECONCILE 64 missing_issue_iid
  [[ -n "$state_labels" ]] || fail LABEL_RECONCILE 64 missing_state_labels
  [[ -n "$category_labels" ]] || fail LABEL_RECONCILE 64 missing_category_labels
  require_glab
  require_node
  issue_json="$(glab issue view "$issue_iid" -R "$repo" -F json)"
  plan="$(ISSUE_JSON="$issue_json" node - "$add_labels" "$remove_labels" "$state_labels" "$category_labels" <<'NODE'
const data = JSON.parse(process.env.ISSUE_JSON || '{}');
const [addArg, removeArg, stateArg, categoryArg] = process.argv.slice(2);
function fail(reason) {
  console.error(`LABEL_RECONCILE result=blocked reason=${reason}`);
  process.exit(2);
}
function parseCsv(value, name) {
  if (!value) return [];
  const labels = value.split(',').map((label) => label.trim()).filter(Boolean);
  for (const label of labels) {
    if (/[\u0000-\u001F\u007F,]/u.test(label)) fail(`invalid_${name}`);
  }
  return [...new Set(labels)];
}
if (!Array.isArray(data.labels) || !data.labels.every((label) => typeof label === 'string')) fail('invalid_current_labels');
const current = parseCsv(data.labels.join(','), 'current_labels');
const add = parseCsv(addArg, 'add_labels');
const remove = parseCsv(removeArg, 'remove_labels');
const stateLabels = new Set(parseCsv(stateArg, 'state_labels'));
const categoryLabels = new Set(parseCsv(categoryArg, 'category_labels'));
const addSet = new Set(add);
for (const label of remove) {
  if (addSet.has(label)) fail('add_remove_label_overlap');
}
const final = new Set(current);
for (const label of remove) final.delete(label);
for (const label of add) final.add(label);
const finalLabels = [...final];
const stateFinal = finalLabels.filter((label) => stateLabels.has(label));
const categoryFinal = finalLabels.filter((label) => categoryLabels.has(label));
if (stateFinal.length > 1) fail('state_label_conflict');
if (categoryFinal.length > 1) fail('category_label_conflict');
const currentSet = new Set(current);
const addActual = add.filter((label) => !currentSet.has(label));
const removeActual = remove.filter((label) => currentSet.has(label));
process.stdout.write(JSON.stringify({add: addActual, remove: removeActual, final: finalLabels}));
NODE
)"
  add_csv="$(json_field "$plan" add | node -e 'const labels=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(labels.join(","));')"
  remove_csv="$(json_field "$plan" remove | node -e 'const labels=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(labels.join(","));')"
  final_csv="$(json_field "$plan" final | node -e 'const labels=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(labels.join(","));')"
  if [[ -z "$add_csv" && -z "$remove_csv" ]]; then
    echo "LABEL_RECONCILE result=no_change issue=$issue_iid final=$final_csv"
    return 0
  fi
  local cmd=(glab issue update "$issue_iid" -R "$repo")
  [[ -z "$add_csv" ]] || cmd+=(--label "$add_csv")
  [[ -z "$remove_csv" ]] || cmd+=(--unlabel "$remove_csv")
  "${cmd[@]}"
  echo "LABEL_RECONCILE result=updated issue=$issue_iid add=${add_csv:-none} remove=${remove_csv:-none} final=$final_csv"
}

safe_mr_json() {
  local repo="" mr_iid="" project_path="" expected_source="" expected_target="" raw_json
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --mr-iid) mr_iid="${2:-}"; shift 2 ;;
      --project-path) project_path="${2:-}"; shift 2 ;;
      --expected-source-branch) expected_source="${2:-}"; shift 2 ;;
      --expected-target-branch) expected_target="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail SAFE_MR_JSON 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail SAFE_MR_JSON 64 missing_repo
  [[ -n "$mr_iid" ]] || fail SAFE_MR_JSON 64 missing_mr_iid
  [[ -n "$project_path" ]] || fail SAFE_MR_JSON 64 missing_project_path
  require_glab
  require_node
  raw_json="$(glab mr view "$mr_iid" -R "$repo" -F json)"
  safe_mr_json_from_raw "$raw_json" "$mr_iid" "$project_path" "$expected_source" "$expected_target"
  echo
}

auto_merge_api_fallback() {
  local repo="" project_path="" mr_iid="" reviewed_sha="" source_branch="" target_branch=""
  local merge_authority="" authority_source="" authority_verified="" caller_role="" api_hostname_arg=""
  local raw_json safe_json current_sha pipeline_sha pipeline_status project_encoded merge_output merge_status api_output api_status reviewed_sha_lower api_hostname
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --project-path) project_path="${2:-}"; shift 2 ;;
      --mr-iid) mr_iid="${2:-}"; shift 2 ;;
      --reviewed-sha) reviewed_sha="${2:-}"; shift 2 ;;
      --source-branch) source_branch="${2:-}"; shift 2 ;;
      --target-branch) target_branch="${2:-}"; shift 2 ;;
      --merge-authority) merge_authority="${2:-}"; shift 2 ;;
      --authority-source) authority_source="${2:-}"; shift 2 ;;
      --authority-verified) authority_verified="${2:-}"; shift 2 ;;
      --caller-role) caller_role="${2:-}"; shift 2 ;;
      --hostname) api_hostname_arg="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail AUTO_MERGE 64 "unknown_arg:$1" ;;
    esac
  done
  [[ -n "$repo" ]] || fail AUTO_MERGE 64 missing_repo
  [[ -n "$project_path" ]] || fail AUTO_MERGE 64 missing_project_path
  [[ -n "$mr_iid" ]] || fail AUTO_MERGE 64 missing_mr_iid
  [[ "$reviewed_sha" =~ ^[0-9a-fA-F]{40}$ ]] || fail AUTO_MERGE 64 invalid_reviewed_sha
  [[ -n "$source_branch" ]] || fail AUTO_MERGE 64 missing_source_branch
  [[ -n "$target_branch" ]] || fail AUTO_MERGE 64 missing_target_branch
  [[ "$merge_authority" == "queue auto-merge" ]] || fail AUTO_MERGE 4 unsupported_merge_authority
  [[ -n "$authority_source" ]] || fail AUTO_MERGE 4 missing_authority_source
  [[ "$authority_verified" == "true" ]] || fail AUTO_MERGE 4 authority_source_not_verified
  case "$caller_role" in
    reviewer|authorized-parent|human) ;;
    builder) fail AUTO_MERGE 4 builder_no_finish_authority ;;
    *) fail AUTO_MERGE 4 unknown_caller_role ;;
  esac
  require_glab
  require_node
  reviewed_sha_lower="$(node -e 'process.stdout.write(process.argv[1].toLowerCase())' "$reviewed_sha")"
  api_hostname="$(derive_gitlab_hostname AUTO_MERGE "$repo" "$api_hostname_arg")"
  raw_json="$(glab mr view "$mr_iid" -R "$repo" -F json)"
  safe_json="$(safe_mr_json_from_raw "$raw_json" "$mr_iid" "$project_path" "$source_branch" "$target_branch")"
  current_sha="$(json_field "$safe_json" sha)"
  pipeline_sha="$(json_field "$safe_json" pipeline.sha)"
  pipeline_status="$(json_field "$safe_json" pipeline.status)"
  if [[ "$current_sha" != "$reviewed_sha_lower" ]]; then
    fail AUTO_MERGE 2 head_changed
  fi
  if [[ "$pipeline_sha" != "$reviewed_sha_lower" ]]; then
    fail AUTO_MERGE 3 stale_ci
  fi
  case "$pipeline_status" in
    success) ;;
    pending|running|created) ;;
    *) fail AUTO_MERGE 3 ci_not_queueable ;;
  esac
  set +e
  merge_output="$(glab mr merge "$mr_iid" -R "$repo" --auto-merge --yes --sha "$reviewed_sha" 2>&1)"
  merge_status=$?
  set -e
  if [[ "$merge_status" -eq 0 ]]; then
    echo "AUTO_MERGE result=auto_merge_queued via=glab mr=$mr_iid sha=$reviewed_sha ci=$pipeline_status authority_source=verified"
    return 0
  fi
  if [[ "$merge_output" != *"405"* ]]; then
    fail AUTO_MERGE 5 glab_auto_merge_failed
  fi
  project_encoded="$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$project_path")"
  set +e
  api_output="$(glab api --hostname "$api_hostname" --method PUT "projects/${project_encoded}/merge_requests/${mr_iid}/merge" --field "sha=$reviewed_sha" --field "auto_merge=true" --silent 2>&1)"
  api_status=$?
  set -e
  if [[ "$api_status" -ne 0 ]]; then
    fail AUTO_MERGE 5 api_auto_merge_failed
  fi
  echo "AUTO_MERGE result=auto_merge_queued via=api mr=$mr_iid sha=$reviewed_sha ci=$pipeline_status authority_source=verified"
}

wrapper="${1:-}"
[[ -n "$wrapper" ]] || { usage >&2; exit 64; }
shift || true
case "$wrapper" in
  draft_mr_create) draft_mr_create "$@" ;;
  mr_description_update) mr_description_update "$@" ;;
  issue_note_create) issue_note_create "$@" ;;
  mr_note_create) mr_note_create "$@" ;;
  label_reconcile) label_reconcile "$@" ;;
  safe_mr_json) safe_mr_json "$@" ;;
  auto_merge_api_fallback) auto_merge_api_fallback "$@" ;;
  -h|--help) usage ;;
  *) fail GITLAB_WRAPPER 64 "unknown_wrapper:$wrapper" ;;
esac
