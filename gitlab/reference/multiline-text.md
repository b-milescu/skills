# GitLab multiline text reference

This reference owns the detailed file-backed text patterns for `/gitlab`. The main [`SKILL.md`](../SKILL.md#safe-multiline-gitlab-text) keeps the compatibility heading and short safety summary.

## Safe multiline GitLab text

Use temp/run-dir files plus quoted heredocs for multiline MR notes, issue
notes, and MR descriptions. For MCP paths, read the drafted file into the
MCP `body`/`description` only after `validate_gitlab_text` passes; safe
mutation tools embed that validation. Guarded `glab` fallback may still use
the same local file under snippet fallback conditions. Quoted heredocs
(`<<'EOF'`) keep Markdown backticks, `$VARS`, command substitutions literal
while writing local file.

The MCP validator `validate_gitlab_text` validates MCP bodies before GitLab
mutation; `safe_update_merge_request_description`,
`safe_create_merge_request_note`, and `safe_create_issue_note` embed the same
byte rule. NUL, non-whitespace C0 controls, and DEL are rejected;
tab/newline/carriage return remain valid Markdown. Diagnostics do not print secrets or the malformed packet body; they name failing role and byte offset.

Keep generated text files under temp/run directories, never commit review
artifacts, and redact secrets before writing text that may be pasted to GitLab.
When drafting MR descriptions, keep only the intended auto-close trailer in
plain closing-keyword form (for example `Closes #341`). For any issue the MR
must **not** close, write `issue 410`, `group/project#410`, or `` `#410` ``
instead of a bare `#410` inside non-closing prose such as `does not close`.


## MR note pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/mr-note.md"
cat > "$message_file" <<'EOF'
## Revision Packet

- Reviewed SHA: `abc123`
- Literal example: `echo "$EXAMPLE_VAR"` not executed.
EOF

report_body="$(<"$message_file")"
validate_gitlab_text(role="merge request note", body="$report_body")
safe_create_merge_request_note(project_path, mr_iid, body=report_body, resolvable=false)
```

`safe_create_merge_request_note` posts one top-level non-resolvable MR note for durable Review Reports/status comments; re-read the created note before using it as Review Report evidence.

## Issue note pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/issue-note.md"
cat > "$message_file" <<'EOF'
## Build Handoff

- MR: !123
- Status: ready
EOF

comment_body="$(<"$message_file")"
validate_gitlab_text(role="issue note", body="$comment_body")
safe_create_issue_note(project_path, issue_iid, body=comment_body)
```

## MR description pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
cat > "$description_file" <<'EOF'
# Review Packet

Generated local file Markdown not interpreted by shell.
EOF

description_body="$(<"$description_file")"
validate_gitlab_text(role="merge request description", body="$description_body")
create_merge_request(project_path, source_branch, default_branch, title, description=description_body, draft=true)
safe_update_merge_request_description(project_path, mr_iid, description=description_body)
```

## Inline heredoc command-substitution hazard

Avoid inline heredoc command substitution such as:

```bash
# Do not use: backticks and $() in the body can execute before the transport sees them.
glab mr note create "$mr_iid" --message "$(cat <<EOF
Danger: `date` and $(whoami) may run in the parent shell.
EOF
)"
```

Use the file-backed patterns above instead so Markdown remains literal until the MCP or fallback transport reads the file content.
