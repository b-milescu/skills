# GitLab multiline text reference

This reference owns the detailed file-backed text patterns for `/gitlab-local`. The main [`SKILL.md`](../SKILL.md#safe-multiline-gitlab-text) keeps the compatibility heading and short safety summary.

## Safe multiline GitLab text

Use temp/run-dir files plus quoted heredocs for multiline MR notes, issue notes,
and MR descriptions, then submit those files through
`gitlab-local/scripts/gitlab-wrappers.sh`. Quoted heredocs (`<<'EOF'`) keep
Markdown backticks, `$VARS`, and command substitutions literal while writing the
local file.

The wrappers validate file bytes before calling `glab`: NUL, non-whitespace C0
controls, and DEL are rejected locally, while tab/newline/carriage return remain
valid for Markdown. Diagnostics name the failing file role and byte offset but do
not print secrets or the malformed packet body.

Keep generated text files under temp/run directories, never commit review
artifacts, and redact secrets before writing text that may be pasted to GitLab.

## MR note pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/mr-note.md"
cat > "$message_file" <<'EOF'
## Revision Packet

- Reviewed SHA: `abc123`
- Literal example: `echo "$EXAMPLE_VAR"` is not executed.
EOF

gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" mr_note_create --repo "$repo_url" --mr-iid "$mr_iid" \
  --message-file "$message_file"
```

## Issue note pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/issue-note.md"
cat > "$message_file" <<'EOF'
## Build Handoff

- MR: !123
- Status: ready for review
EOF

gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" issue_note_create --repo "$repo_url" --issue-iid "$issue_iid" \
  --message-file "$message_file"
```

## MR description pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
cat > "$description_file" <<'EOF'
# Review Packet

Generated from a local file so Markdown is not interpreted by the shell.
EOF

gitlab_wrappers_script="skill://gitlab-local/scripts/gitlab-wrappers.sh"
"$gitlab_wrappers_script" draft_mr_create --repo "$repo_url" \
  --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description-file "$description_file"
"$gitlab_wrappers_script" mr_description_update --repo "$repo_url" --mr-iid "$mr_iid" \
  --description-file "$description_file"
```

## Inline heredoc command-substitution hazard

Avoid inline heredoc command substitution such as:

```bash
# Do not use: backticks and $() in the body can execute before glab sees them.
glab mr note create "$mr_iid" --message "$(cat <<EOF
Danger: `date` and $(whoami) may run in the parent shell.
EOF
)"
```

Use the file-backed patterns above instead so Markdown remains literal until `glab` reads the file content.
