#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

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
  body="$(extract_snippet "gitlab-local/SKILL.md" "$name")"
  [[ -n "$body" ]] || fail "gitlab-local/SKILL.md missing snippet $name"
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

assert_contains "$draft_create_body" 'glab mr create --draft' 'Draft MR create command'
assert_contains "$draft_create_body" '--source-branch "$source_branch"' 'Draft MR source branch flag'
assert_not_contains "$draft_create_body" 'glab mr update' 'MR update command in Draft MR create snippet'
assert_not_contains "$draft_create_body" '--ready' 'ready flag in Draft MR create snippet'

assert_contains "$mr_description_update_body" 'glab mr update <id> --description "$(cat "$description_file")"' 'MR description update command'
assert_not_contains "$mr_description_update_body" 'glab mr create' 'MR create command in description update snippet'
assert_not_contains "$mr_description_update_body" '--ready' 'ready flag in description update snippet'

assert_contains "$draft_mark_ready_body" 'glab mr update <id> --ready' 'Draft MR mark-ready command'
assert_not_contains "$draft_mark_ready_body" 'glab mr create' 'MR create command in mark-ready snippet'
assert_not_contains "$draft_mark_ready_body" '--description' 'description update in mark-ready snippet'

assert_contains "$approval_body" 'glab mr approve "$mr_iid" --sha "$reviewed_sha"' 'SHA-bound approval command'
assert_not_contains "$approval_body" 'glab mr merge' 'merge command in approval snippet'
assert_not_contains "$approval_body" 'glab api' 'approval confirmation command in approval snippet'

assert_contains "$merge_body" 'glab mr merge "$mr_iid" --yes --sha "$reviewed_sha" --auto-merge=false' 'SHA-bound direct merge command'
assert_not_contains "$merge_body" 'glab mr approve' 'approval command in merge snippet'
assert_not_contains "$merge_body" 'glab mr merge "$mr_iid" --auto-merge --yes' 'auto-merge queueing in direct merge snippet'
assert_not_contains "$merge_body" 'glab api' 'approval confirmation command in merge snippet'

assert_contains "$auto_merge_body" 'glab mr merge "$mr_iid" --auto-merge --yes --sha "$reviewed_sha"' 'SHA-bound auto-merge queue command'
assert_not_contains "$auto_merge_body" 'glab mr approve' 'approval command in auto-merge snippet'
assert_not_contains "$auto_merge_body" 'glab api' 'approval confirmation command in auto-merge snippet'

assert_contains "$confirmation_body" '/merge_requests/${mr_iid}/approvals' 'approval confirmation endpoint'
assert_not_contains "$confirmation_body" 'glab mr approve' 'approval command in confirmation snippet'
assert_not_contains "$confirmation_body" 'glab mr merge' 'merge command in confirmation snippet'

assert_contains "$ci_watch_body" 'scripts/gitlab-ci-watch.sh' 'CI watcher helper script pointer'
assert_contains "$ci_watch_body" 'gitlab_ci_watch_script="skill://gitlab-local/scripts/gitlab-ci-watch.sh"' 'CI watcher full skill URI helper path'
assert_contains "$ci_watch_body" 'scripts/README.md' 'CI watcher helper docs pointer'
assert_contains "$finish_body" 'scripts/gitlab-finish-mr.sh' 'finish helper script pointer'
assert_contains "$finish_body" 'gitlab_finish_mr_script="skill://gitlab-local/scripts/gitlab-finish-mr.sh"' 'finish full skill URI helper path'
assert_contains "$finish_body" 'scripts/README.md' 'finish helper docs pointer'
assert_not_contains "$ci_watch_body" 'while [ "$SECONDS" -le "$deadline" ]; do' 'long CI watcher shell body'
assert_not_contains "$ci_watch_body" 'branch_json="$(glab ci status --branch "$source_branch" -F json 2>/dev/null || true)"' 'inline branch CI status body'
assert_not_contains "$finish_body" 'case "$caller_role:$merge_authority" in' 'long authority switch shell body'
assert_not_contains "$finish_body" 'git worktree remove "$worktree_path"' 'inline worktree cleanup body'

assert_contains "$mr_note_body" 'glab mr note create <id> --message "$(cat "$report_file")"' 'MR note command'
assert_not_contains "$mr_note_body" 'glab issue note' 'issue-note command in MR-note snippet'
assert_contains "$mr_note_body" 'report_file="$run_dir/mr-report.md"' 'file-backed MR report path'

assert_contains "$issue_note_body" 'glab issue note <id> --message "$(cat "$comment_file")"' 'issue note command'
assert_not_contains "$issue_note_body" 'glab mr note create' 'MR-note command in issue-note snippet'
assert_contains "$issue_note_body" 'comment_file="$run_dir/issue-note.md"' 'file-backed issue note path'

require_text "gitlab-local/SKILL.md" 'Use file-backed long descriptions/messages' 'file-backed multiline guidance'
require_text "gitlab-local/SKILL.md" 'Before any flagged `glab` command, run exact command help' 'help-first rule'

require_text "gitlab-local/scripts/README.md" 'gitlab-ci-watch\.sh.*ci-watch-sha-pinned' 'CI watcher README contract reference'
require_text "gitlab-local/scripts/README.md" 'gitlab-finish-mr\.sh.*finish-mr-authority-aware' 'finish README contract reference'
require_text "gitlab-local/scripts/README.md" 'no live GitLab mutation' 'fake-helper-test safety note'

if grep -Fq 'Snippet: approve-merge-sha-bound' gitlab-local/SKILL.md; then
  fail 'retired combined approve-merge-sha-bound snippet still present'
fi

if grep -Fq 'Snippet: note-comment-creation' gitlab-local/SKILL.md; then
  fail 'retired combined note-comment-creation snippet still present'
fi

if grep -Fq 'Snippet: draft-mr-create-update' gitlab-local/SKILL.md; then
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

require_text "gitlab-local/SKILL.md" 'Snippet: issue-note-create' 'issue-note snippet reference'
require_text "start-build/reference/post-merge-verifier.md" 'Snippet: issue-note-create' 'post-merge issue-note snippet reference'

require_text \
  "gitlab-local/SKILL.md" \
  'Choose (exactly )?one action' \
  'choose-one-action warning for approval/merge snippets'
require_text \
  "gitlab-local/SKILL.md" \
  'Never run[^.]*combined[^.]*approval/merge block' \
  'no combined approval/merge block warning'

for file in start-review/SKILL.md start-review/REVIEW-FLOW.md; do
  if grep -Fq 'approve-merge-sha-bound' "$file"; then
    fail "$file still references retired combined approve-merge-sha-bound snippet"
  fi
  require_text "$file" 'Snippet: sha-bound-approval' 'sha-bound approval snippet reference'
  require_text "$file" 'Snippet: sha-bound-merge' 'sha-bound merge snippet reference'
  require_text "$file" 'Snippet: sha-bound-auto-merge-queue' 'sha-bound auto-merge queue snippet reference'
done

# Keep executable action snippets isolated. The authority-aware finish helper is
# intentionally allowed to contain conditional approve+merge logic; generic
# snippet sections must not reintroduce a copy-paste block that performs both.
awk '
  /^### Snippet:/ {
    if (snippet != "" && snippet != "finish-mr-authority-aware" && saw_approve && saw_merge) {
      printf "snippet %s contains both glab mr approve and glab mr merge\n", snippet > "/dev/stderr"
      bad=1
    }
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_approve=0
    saw_merge=0
    next
  }
  snippet != "" && /^[[:space:]]*glab mr approve[[:space:]]/ { saw_approve=1 }
  snippet != "" && /^[[:space:]]*glab mr merge[[:space:]]/ { saw_merge=1 }
  END {
    if (snippet != "" && snippet != "finish-mr-authority-aware" && saw_approve && saw_merge) {
      printf "snippet %s contains both glab mr approve and glab mr merge\n", snippet > "/dev/stderr"
      bad=1
    }
    exit bad ? 1 : 0
  }
' gitlab-local/SKILL.md || fail 'combined executable approve+merge snippet detected'

awk '
  /^### Snippet:/ {
    if (snippet != "" && saw_create && saw_description_update && saw_ready) {
      printf "snippet %s contains create, description update, and ready commands\n", snippet > "/dev/stderr"
      bad=1
    }
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_create=0
    saw_description_update=0
    saw_ready=0
    next
  }
  snippet != "" && /^[[:space:]]*glab mr create[[:space:]]/ { saw_create=1 }
  snippet != "" && /^[[:space:]]*glab mr update[[:space:]].*--description/ { saw_description_update=1 }
  snippet != "" && /^[[:space:]]*glab mr update[[:space:]].*--ready/ { saw_ready=1 }
  END {
    if (snippet != "" && saw_create && saw_description_update && saw_ready) {
      printf "snippet %s contains create, description update, and ready commands\n", snippet > "/dev/stderr"
      bad=1
    }
    exit bad ? 1 : 0
  }
' gitlab-local/SKILL.md || fail 'combined executable create+description-update+ready snippet detected'

awk '
  /^### Snippet:/ {
    if (snippet != "" && saw_mr_note && saw_issue_note) {
      printf "snippet %s contains both glab mr note create and glab issue note\n", snippet > "/dev/stderr"
      bad=1
    }
    snippet=$0
    sub(/^### Snippet: /, "", snippet)
    saw_mr_note=0
    saw_issue_note=0
    next
  }
  snippet != "" && /^[[:space:]]*glab mr note create[[:space:]]/ { saw_mr_note=1 }
  snippet != "" && /^[[:space:]]*glab issue note[[:space:]]/ { saw_issue_note=1 }
  END {
    if (snippet != "" && saw_mr_note && saw_issue_note) {
      printf "snippet %s contains both glab mr note create and glab issue note\n", snippet > "/dev/stderr"
      bad=1
    }
    exit bad ? 1 : 0
  }
' gitlab-local/SKILL.md || fail 'combined executable MR+issue note snippet detected'

printf 'gitlab-local-split-snippets: PASS\n'
