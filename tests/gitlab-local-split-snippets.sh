#!/usr/bin/env bash
set -euo pipefail

# Parallel-execution contract (issue #197/#210):
#   Snippet body/stability assertions live here.
#   CI/finish guard mechanics live in tests/gitlab-local-ci-finish-guards.sh.
# These two test files are intentionally disjoint so future changes can update
# snippet inventory separately from CI/finish mechanics.
# both, merge test rows by ID without resequencing the existing assertions.
#
# MCP-first transport contract (issue #210):
#   This test asserts BEHAVIOURAL invariants, stable snippet names, and guarded
#   fallback/helper contracts, NOT unconditional primary `glab` command strings.
#   Per-snippet MCP primary tool/input/output/fail-closed/fallback details live
#   in gitlab-local/reference/snippet-transports.md; inline SKILL shell blocks
#   are accepted fallback/helper examples.
#     - the 20 snippet NAMES are stable (transport-independent API),
#     - one action per snippet (no snippet mixes two mutating verbs),
#     - no combined approve+merge in any generic snippet (only the
#       finish-mr-authority-aware facade may carry conditional approve+merge),
#     - helper-script path contracts survive (skill:// URIs + scripts/README.md),
#     - file-backed / explicit-target inputs survive for note + description flows,
#     - retired combined snippets (approve-merge-sha-bound, note-comment-creation,
#       draft-mr-create-update) stay gone.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

SKILL="gitlab-local/SKILL.md"

fail() {
  printf 'gitlab-local-split-snippets: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

extract_snippet() {
  local file="$1" name="$2"
  awk -v heading="### Snippet: $name" '
    $0 == heading { in_section=1; next }
    in_section && /^### Snippet:/ { exit }
    in_section { print }
  ' "$file"
}

require_snippet() {
  local name="$1" body
  body="$(extract_snippet "$SKILL" "$name")"
  [[ -n "$body" ]] || fail "$SKILL missing snippet $name"
  printf '%s\n' "$body"
}

assert_contains() {
  local text="$1" needle="$2" label="$3"
  [[ "$text" == *"$needle"* ]] || fail "missing $label: $needle"
}

assert_not_contains() {
  local text="$1" needle="$2" label="$3"
  [[ "$text" != *"$needle"* ]] || fail "unexpected $label: $needle"
}

# Behavioural matcher: a snippet "performs <verb>" if its body contains the verb
# in EITHER transport — a guarded `glab` fallback/helper form OR an MCP tool call.
# These regexes deliberately avoid pinning exact fallback arguments so the
# assertions stay green across MCP/fallback implementation changes.
assert_performs() {
  local text="$1" pattern="$2" label="$3"
  printf '%s\n' "$text" | grep -Eiq -- "$pattern" || fail "snippet does not perform $label"
}

assert_not_performs() {
  local text="$1" pattern="$2" label="$3"
  if printf '%s\n' "$text" | grep -Eiq -- "$pattern"; then
    fail "snippet unexpectedly performs $label"
  fi
}

# SHA-pin invariant (transport-independent): the action line that performs the
# mutating verb must bind reviewed_sha ON THE SAME LINE, so the action is pinned
# to the reviewed head and cannot drift. This matches guarded `glab ... --sha
# "$reviewed_sha"` and MCP `tool(..., sha="$reviewed_sha")` forms, but rejects
# a body that merely declares reviewed_sha elsewhere without binding it to the action.
assert_action_sha_pinned() {
  local text="$1" verb="$2" label="$3"
  printf '%s\n' "$text" \
    | grep -Ei -- "$verb" \
    | grep -Eiq -- '(--sha[ =]|sha[ ]*[:=][ ]*)"?\$reviewed_sha' \
    || fail "$label action line is not SHA-pinned to reviewed_sha"
}

# Transport-independent action-verb regexes. Each matches the guarded `glab`
# fallback wording and the gitlab-mcp tool-call wording used by the primary
# contracts (create_merge_request / update_merge_request / approve_merge_request /
# merge_merge_request / get_merge_request / list_pipelines / create_note).
VERB_MR_CREATE='glab mr create|create_merge_request'
VERB_MR_UPDATE='glab mr update|update_merge_request'
VERB_MARK_READY='glab mr update[^|]*--ready|update_merge_request[^|]*ready|--ready|ready ?[:=] ?true'
VERB_DESCRIPTION='--description|description'
VERB_APPROVE='glab mr approve|approve_merge_request'
VERB_MERGE='glab mr merge|merge_merge_request'
VERB_AUTO_MERGE='--auto-merge|auto[_-]?merge'
VERB_APPROVALS_ENDPOINT='/approvals|get_merge_request_approval|approval_state'
VERB_MR_NOTE='glab mr note|create_note|mr_note_create'
VERB_ISSUE_NOTE='glab issue note|create_issue_note|issue_note_create'

draft_create_body="$(require_snippet draft-mr-create)"
mr_description_update_body="$(require_snippet mr-description-update)"
draft_mark_ready_body="$(require_snippet draft-mr-mark-ready)"
approval_body="$(require_snippet sha-bound-approval)"
merge_body="$(require_snippet sha-bound-merge)"
auto_merge_body="$(require_snippet sha-bound-auto-merge-queue)"
confirmation_body="$(require_snippet approval-confirmation)"
ci_watch_body="$(require_snippet ci-watch-sha-pinned)"
finish_body="$(require_snippet finish-mr-authority-aware)"
mr_note_body="$(require_snippet mr-note-create)"
issue_note_body="$(require_snippet issue-note-create)"
label_reconcile_body="$(require_snippet label-reconcile)"
safe_mr_json_body="$(require_snippet safe-mr-json)"
auto_merge_api_body="$(require_snippet auto-merge-api-fallback)"

# --- Snippet-name stability: the 20 stable snippet names exist ----------------
# The names are the transport-independent API workflow skills depend on; they
# must remain stable across MCP primary and fallback/helper implementations.
for name in \
  local-repo-preflight issue-pickup draft-mr-create mr-description-update \
  draft-mr-mark-ready mr-pickup artifact-capture ci-decision-snapshot \
  ci-watch-sha-pinned mr-note-create issue-note-create label-reconcile \
  safe-mr-json auto-merge-api-fallback sha-guard sha-bound-approval \
  sha-bound-merge sha-bound-auto-merge-queue approval-confirmation \
  finish-mr-authority-aware; do
  grep -Fxq "### Snippet: $name" "$SKILL" || fail "missing stable snippet name $name"
done
snippet_count="$(grep -cE '^### Snippet:' "$SKILL")"
[[ "$snippet_count" -eq 20 ]] || fail "expected exactly 20 snippet names, found $snippet_count"


CONTRACT="gitlab-local/reference/snippet-transports.md"
[[ -f "$CONTRACT" ]] || fail "missing snippet transport contract $CONTRACT"
require_text "$SKILL" 'reference/snippet-transports\.md' 'snippet transport contract link'
require_text "$CONTRACT" 'MCP primary tool' 'MCP primary tools column'
require_text "$CONTRACT" 'Fail-closed checks' 'fail-closed checks column'
require_text "$CONTRACT" 'Fallback condition' 'fallback condition column'
require_text "$CONTRACT" 'Post-mutation MCP re-read' 'post-mutation re-read column'
for name in \
  local-repo-preflight issue-pickup draft-mr-create mr-description-update \
  draft-mr-mark-ready mr-pickup artifact-capture ci-decision-snapshot \
  ci-watch-sha-pinned mr-note-create issue-note-create label-reconcile \
  safe-mr-json auto-merge-api-fallback sha-guard sha-bound-approval \
  sha-bound-merge sha-bound-auto-merge-queue approval-confirmation \
  finish-mr-authority-aware; do
  require_text "$CONTRACT" "\`$name\`" "transport contract for $name"
done
# --- Draft MR create: creates an MR, file-backed description, no ready/update --
# One action: it CREATES, it does not update an existing MR and does not mark ready.
assert_contains "$draft_create_body" 'gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"' 'Draft MR create wrapper path'
assert_contains "$draft_create_body" 'draft_mr_create' 'Draft MR create wrapper command'
assert_contains "$draft_create_body" '--source-branch "$source_branch"' 'Draft MR source branch input'
assert_contains "$draft_create_body" '--description-file "$description_file"' 'Draft MR file-backed description'
assert_performs "$draft_create_body" "$VERB_MR_CREATE" 'an MR-create action'
assert_not_performs "$draft_create_body" "$VERB_MR_UPDATE" 'an MR-update action in the create snippet'
assert_not_performs "$draft_create_body" "$VERB_MARK_READY" 'a mark-ready action in the create snippet'

# --- MR description update: updates description, explicit target, no create/ready
assert_contains "$mr_description_update_body" 'gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"' 'MR description update wrapper path'
assert_contains "$mr_description_update_body" 'mr_description_update' 'MR description update wrapper command'
assert_contains "$mr_description_update_body" '--mr-iid "$mr_iid"' 'MR description explicit target'
assert_contains "$mr_description_update_body" '--description-file "$description_file"' 'MR description file-backed input'
assert_performs "$mr_description_update_body" "$VERB_DESCRIPTION" 'a description action'
assert_not_performs "$mr_description_update_body" "$VERB_MR_CREATE" 'an MR-create action in the description-update snippet'
assert_not_performs "$mr_description_update_body" "$VERB_MARK_READY" 'a mark-ready action in the description-update snippet'

# --- Draft MR mark-ready: marks ready only, no create/description -------------
assert_performs "$draft_mark_ready_body" "$VERB_MARK_READY" 'a mark-ready action'
assert_not_performs "$draft_mark_ready_body" "$VERB_MR_CREATE" 'an MR-create action in the mark-ready snippet'
assert_not_contains "$draft_mark_ready_body" '--description' 'description update in mark-ready snippet'

# --- SHA-bound approval: approves, SHA-pinned, no merge / no approvals read ----
# Authority-relevant invariant: approval is its own action, bound to reviewed_sha.
assert_performs "$approval_body" "$VERB_APPROVE" 'an approve action'
assert_action_sha_pinned "$approval_body" "$VERB_APPROVE" 'approval'
assert_not_performs "$approval_body" "$VERB_MERGE" 'a merge action in the approval snippet'
assert_not_performs "$approval_body" "$VERB_APPROVALS_ENDPOINT" 'an approvals-read action in the approval snippet'

# --- SHA-bound direct merge: merges, SHA-pinned, not auto-merge, no approve ----
assert_performs "$merge_body" "$VERB_MERGE" 'a merge action'
assert_action_sha_pinned "$merge_body" "$VERB_MERGE" 'merge'
assert_not_performs "$merge_body" "$VERB_APPROVE" 'an approve action in the merge snippet'
assert_not_performs "$merge_body" "$VERB_APPROVALS_ENDPOINT" 'an approvals-read action in the merge snippet'

# --- SHA-bound auto-merge queue: queues auto-merge, SHA-pinned, no approve -----
assert_performs "$auto_merge_body" "$VERB_MERGE" 'a merge action'
assert_performs "$auto_merge_body" "$VERB_AUTO_MERGE" 'an auto-merge queue action'
assert_action_sha_pinned "$auto_merge_body" "$VERB_MERGE" 'auto-merge queue'
assert_not_performs "$auto_merge_body" "$VERB_APPROVE" 'an approve action in the auto-merge snippet'
assert_not_performs "$auto_merge_body" "$VERB_APPROVALS_ENDPOINT" 'an approvals-read action in the auto-merge snippet'

# --- Approval confirmation: reads approvals only, no approve/merge -------------
assert_performs "$confirmation_body" "$VERB_APPROVALS_ENDPOINT" 'an approvals-read action'
assert_not_performs "$confirmation_body" "$VERB_APPROVE" 'an approve action in the confirmation snippet'
assert_not_performs "$confirmation_body" "$VERB_MERGE" 'a merge action in the confirmation snippet'

# --- CI watch + finish: keep helper-script path contracts + card link ---------
# The bodies must point at the in-skill helper script + docs (path contracts that
# survive transport changes), and must not re-inline the long relocated bodies.
assert_contains "$ci_watch_body" 'scripts/gitlab-ci-watch.sh' 'CI watcher helper script pointer'
assert_contains "$ci_watch_body" 'gitlab_ci_watch_script="skill://gitlab-local/scripts/gitlab-ci-watch.sh"' 'CI watcher full skill URI helper path'
assert_contains "$ci_watch_body" 'scripts/README.md' 'CI watcher helper docs pointer'
assert_contains "$finish_body" 'scripts/gitlab-finish-mr.sh' 'finish helper script pointer'
assert_contains "$finish_body" 'gitlab_finish_mr_script="skill://gitlab-local/scripts/gitlab-finish-mr.sh"' 'finish full skill URI helper path'
assert_contains "$finish_body" 'scripts/README.md' 'finish helper docs pointer'
assert_not_contains "$ci_watch_body" 'while [ "$SECONDS" -le "$deadline" ]; do' 'long CI watcher shell body'
assert_not_contains "$finish_body" 'case "$caller_role:$merge_authority" in' 'long authority switch shell body'
assert_not_contains "$finish_body" 'git worktree remove "$worktree_path"' 'inline worktree cleanup body'

# --- MR note: posts an MR note via helper, file-backed, not an issue note ------
assert_contains "$mr_note_body" 'scripts/gitlab-wrappers.sh' 'MR note wrapper script pointer'
assert_contains "$mr_note_body" 'mr_note_create' 'MR note wrapper command'
assert_contains "$mr_note_body" '--mr-iid "$mr_iid"' 'explicit MR target'
assert_contains "$mr_note_body" '--message-file "$report_file"' 'file-backed MR message'
assert_not_performs "$mr_note_body" "$VERB_ISSUE_NOTE" 'an issue-note action in the MR-note snippet'

# --- Issue note: posts an issue note via helper, file-backed, not an MR note ---
assert_contains "$issue_note_body" 'scripts/gitlab-wrappers.sh' 'issue note wrapper script pointer'
assert_contains "$issue_note_body" 'issue_note_create' 'issue note wrapper command'
assert_contains "$issue_note_body" '--issue-iid "$issue_iid"' 'explicit issue target'
assert_contains "$issue_note_body" '--message-file "$comment_file"' 'file-backed issue message'
assert_not_performs "$issue_note_body" "$VERB_MR_NOTE" 'an MR-note action in the issue-note snippet'

# --- Label reconcile / safe MR JSON / auto-merge fallback: wrapper contracts ---
assert_contains "$label_reconcile_body" 'gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"' 'label reconcile self-contained wrapper script path'
assert_contains "$label_reconcile_body" 'label_reconcile' 'label reconcile wrapper command'
assert_contains "$label_reconcile_body" '--add-labels "$add_labels"' 'label reconcile add input'
assert_contains "$label_reconcile_body" '--remove-labels "$remove_labels"' 'label reconcile remove input'
assert_contains "$label_reconcile_body" 'state/category label conflicts' 'label conflict fail-closed docs'
assert_contains "$safe_mr_json_body" 'gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"' 'safe MR JSON self-contained wrapper script path'
assert_contains "$safe_mr_json_body" 'safe_mr_json' 'safe MR JSON wrapper command'
assert_contains "$safe_mr_json_body" 'project binding, SHA, pipeline' 'safe MR JSON fail-closed docs'
assert_contains "$auto_merge_api_body" 'gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"' 'auto-merge fallback self-contained wrapper script path'
assert_contains "$auto_merge_api_body" 'auto_merge_api_fallback' 'auto-merge fallback wrapper command'
assert_contains "$auto_merge_api_body" '--authority-verified true' 'verified authority source input'
require_text "gitlab-local/scripts/README.md" 'gitlab-wrappers\.sh.*draft-mr-create.*mr-description-update' 'wrappers README description contract reference'

# --- File-backed multiline + help-first guidance survive ----------------------
require_text "$SKILL" 'Use file-backed long descriptions/messages' 'file-backed multiline guidance'
require_text "$SKILL" 'validate text files for NUL/control-character corruption' 'control-character validation guidance'
require_text "gitlab-local/reference/multiline-text.md" 'do not print secrets or the malformed packet body' 'malformed body redaction guidance'
require_text "$SKILL" 'Before any flagged fallback `glab` command, run exact command help' 'fallback help-first rule'

require_text "gitlab-local/scripts/README.md" 'gitlab-ci-watch\.sh.*ci-watch-sha-pinned' 'CI watcher README contract reference'
require_text "gitlab-local/scripts/README.md" 'gitlab-finish-mr\.sh.*finish-mr-authority-aware' 'finish README contract reference'
require_text "gitlab-local/scripts/README.md" 'gitlab-wrappers\.sh.*auto-merge-api-fallback' 'wrappers README contract reference'
require_text "gitlab-local/scripts/README.md" 'no live GitLab mutation' 'fake-helper-test safety note'

# --- Retired combined snippets stay gone (transport-independent names) ---------
if grep -Fq 'Snippet: approve-merge-sha-bound' "$SKILL"; then
  fail 'retired combined approve-merge-sha-bound snippet still present'
fi
if grep -Fq 'Snippet: note-comment-creation' "$SKILL"; then
  fail 'retired combined note-comment-creation snippet still present'
fi
if grep -Fq 'Snippet: draft-mr-create-update' "$SKILL"; then
  fail 'retired combined draft-mr-create-update snippet still present'
fi

for file in \
  gitlab-local/SKILL.md \
  start-build/SKILL.md \
  start-build/BUILD-FLOW.md \
  agents/claude/mr-builder.md \
  agents/pi/mr-builder.md; do
  if grep -Fq 'draft-mr-create-update' "$file"; then
    fail "$file still references retired combined draft-mr-create-update snippet"
  fi
done

for file in start-build/SKILL.md start-build/BUILD-FLOW.md; do
  require_text "$file" 'Snippet: draft-mr-create' 'Draft MR create snippet reference'
  require_text "$file" 'Snippet: mr-description-update' 'MR description update snippet reference'
  require_text "$file" 'Snippet: draft-mr-mark-ready' 'Draft MR mark-ready snippet reference'
done

for file in \
  gitlab-local/SKILL.md \
  start-review/SKILL.md \
  start-review/REVIEW-FLOW.md \
  start-review/templates/filling-guide.md \
  agents/claude/mr-reviewer.md \
  agents/pi/mr-reviewer.md \
  start-build/BUILD-FLOW.md \
  start-build/reference/stuck-protocol.md; do
  if grep -Fq 'note-comment-creation' "$file"; then
    fail "$file still references retired combined note-comment-creation snippet"
  fi
done

for file in \
  start-review/SKILL.md \
  start-review/REVIEW-FLOW.md \
  start-review/templates/filling-guide.md \
  start-review/templates/review-report.md \
  start-review/templates/unblock-response.md \
  agents/claude/mr-reviewer.md \
  agents/pi/mr-reviewer.md; do
  require_text "$file" 'Snippet: mr-note-create' 'MR-note snippet reference'
  if grep -Fq 'Snippet: issue-note-create' "$file"; then
    fail "$file references issue-note-create in MR review posting guidance"
  fi
done

require_text "$SKILL" 'Snippet: issue-note-create' 'issue-note snippet reference'
require_text "start-build/reference/post-merge-verifier.md" 'Snippet: issue-note-create' 'post-merge issue-note snippet reference'

# --- No-combined-approve+merge warning survives (transport-independent prose) --
require_text "$SKILL" 'Choose (exactly )?one action' 'choose-one-action warning for approval/merge snippets'
require_text "$SKILL" 'Never run[^.]*combined[^.]*approval/merge block' 'no combined approval/merge block warning'

for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  if grep -Fq 'approve-merge-sha-bound' "$file"; then
    fail "$file still references retired combined approve-merge-sha-bound snippet"
  fi
  require_text "$file" 'Snippet: sha-bound-approval' 'sha-bound approval snippet reference'
  require_text "$file" 'Snippet: sha-bound-merge' 'sha-bound merge snippet reference'
  require_text "$file" 'Snippet: sha-bound-auto-merge-queue' 'sha-bound auto-merge queue snippet reference'
done

# --- One-action-per-snippet (no combined approve+merge), transport-independent -
# The authority-aware finish helper is intentionally allowed to carry conditional
# approve+merge logic; every OTHER snippet section must not perform BOTH an
# approve action and a merge action. The verb regexes match either guarded
# fallback `glab` wording or gitlab-mcp tool-call wording, so this fail-closed
# guard survives transport implementation changes.
awk '
  function flush() {
    if (snippet != "" && snippet != "finish-mr-authority-aware" && saw_approve && saw_merge) {
      printf "snippet %s performs both an approve and a merge action\n", snippet > "/dev/stderr"
      bad=1
    }
  }
  /^### Snippet:/ {
    flush()
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_approve=0
    saw_merge=0
    next
  }
  snippet != "" && (/glab mr approve/ || /approve_merge_request/) { saw_approve=1 }
  snippet != "" && (/glab mr merge/ || /merge_merge_request/) { saw_merge=1 }
  END { flush(); exit bad ? 1 : 0 }
' "$SKILL" || fail 'combined approve+merge snippet detected'

# --- One-action-per-snippet (no create+description+ready facade) ---------------
awk '
  function flush() {
    if (snippet != "" && saw_create && saw_description && saw_ready) {
      printf "snippet %s performs create, description update, and ready actions\n", snippet > "/dev/stderr"
      bad=1
    }
  }
  /^### Snippet:/ {
    flush()
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_create=0
    saw_description=0
    saw_ready=0
    next
  }
  snippet != "" && (/glab mr create/ || /create_merge_request/) { saw_create=1 }
  snippet != "" && ((/glab mr update/ && /--description/) || (/update_merge_request/ && /description/)) { saw_description=1 }
  snippet != "" && ((/glab mr update/ && /--ready/) || (/update_merge_request/ && /ready/)) { saw_ready=1 }
  END { flush(); exit bad ? 1 : 0 }
' "$SKILL" || fail 'combined create+description-update+ready snippet detected'

# --- One-action-per-snippet (no combined MR-note + issue-note) -----------------
awk '
  function flush() {
    if (snippet != "" && saw_mr_note && saw_issue_note) {
      printf "snippet %s performs both an MR-note and an issue-note action\n", snippet > "/dev/stderr"
      bad=1
    }
  }
  /^### Snippet:/ {
    flush()
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_mr_note=0
    saw_issue_note=0
    next
  }
  snippet != "" && (/glab mr note/ || /create_note/) { saw_mr_note=1 }
  snippet != "" && (/glab issue note/ || /create_issue_note/) { saw_issue_note=1 }
  END { flush(); exit bad ? 1 : 0 }
' "$SKILL" || fail 'combined MR+issue note snippet detected'

printf 'gitlab-local-split-snippets: PASS\n'
