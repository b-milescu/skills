# GitLab multiline text reference

This reference owns the detailed file-backed text patterns for `/gitlab-local`. The main [`SKILL.md`](../SKILL.md#safe-multiline-gitlab-text) keeps the compatibility heading and short safety summary.

## Safe multiline GitLab text

Use temp/run-dir files plus quoted heredocs for multiline MR notes, issue notes, and MR descriptions. Quoted heredocs (`<<'EOF'`) keep Markdown backticks, `$VARS`, and command substitutions literal while writing the local file.

Keep generated text files under temp/run directories, never commit review artifacts, and redact secrets before writing text that may be pasted to GitLab.

## MR note pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
message_file="$run_dir/mr-note.md"
cat > "$message_file" <<'EOF'
## Review Gate Summary

- Reviewed SHA: `abc123`
- Result: approved
- Literal example: `echo "$EXAMPLE_VAR"` is not executed.
EOF

glab mr note create "$mr_iid" --message "$(cat "$message_file")"
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

glab issue note "$issue_iid" --message "$(cat "$message_file")"
```

## MR description pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
cat > "$description_file" <<'EOF'
# Review Packet

Generated from a local file so Markdown is not interpreted by the shell.
EOF

glab mr create --draft --target-branch "$default_branch" --source-branch "$source_branch" \
  --title "$title" --description "$(cat "$description_file")" --yes
glab mr update "$mr_iid" --description "$(cat "$description_file")"
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
