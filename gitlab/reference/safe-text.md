# GitLab safe-text reference

Transport-agnostic safety rules for any text body submitted to GitLab — MR/issue descriptions and notes — whatever transport carries it.

The [`GitLab Mutation Guard`](mutation-guard.md) calls this the **Safe GitLab Text** phase; a content-byte failure blocks both MCP and fallback before any body-bearing GitLab mutation.

## Content-byte rule

A GitLab text body is byte-safe only when it contains no NUL byte, no
non-whitespace C0 control character, and no DEL (`0x7f`). Tab (`0x09`), newline
(`0x0a`), and carriage return (`0x0d`) stay valid because Markdown bodies use
them. Reject the body before any GitLab write when it violates this rule.

The MCP validator `validate_gitlab_text` owns the active workflow contract for this rule. Body-bearing MCP mutation helpers (`safe_update_merge_request_description`, `safe_create_merge_request_note`, `safe_create_issue_note`) apply the same rule before sending text to GitLab.

`validate_gitlab_text` accepts `content` plus an optional `role` (`body`, `description`, `note`, `review_packet`, or `reviewer_lift`) and fails closed on NUL, non-whitespace C0 controls, DEL, or malformed UTF-16. Diagnostics name the role and offending offset and **never print body**, so malformed secret-bearing payload is not echoed back.

## MR body issue-reference intent

GitLab's MR auto-close parser does **not** understand negation. A sentence like
`does not close #410` still leaves closing language adjacent to a bare `#410`,
so merge may auto-close issue `#410` anyway.

When an MR or issue body mentions an issue it must **not** close, avoid bare
`#N` in non-closing prose. Prefer one of these safe forms instead:

- `issue 410`
- `group/project#410`
- `` `#410` ``

Keep the real auto-close trailer deliberate and unique: use a plain standalone
`Closes #<target>` line only for the issue the MR should close.

```text
validate_gitlab_text(role="description", content=body)
# PASS: no NUL, non-whitespace C0 controls, or DEL
# FAIL: role + byte offset only; body is not printed
```

MCP callers that pass a `body` or `description` string validate it before mutation, or use a safe mutation tool embedding the validator; validation is not a substitute for authored-source readback equality. Read file-backed text without losing authored bytes, including trailing newlines.

## Inline heredoc command-substitution hazard

When building a multiline body in the shell, do not use inline heredoc command
substitution: backticks and `$()` in the body can execute in the parent shell
before the text is ever sent to GitLab.

```bash
# Do not use: backticks and $() in the body can execute before the text is sent.
glab mr note create "$mr_iid" --message "$(cat <<EOF
Danger: `date` and $(whoami) may run in the parent shell.
EOF
)"
```

Write the body to a temp/run-dir file with a **quoted** heredoc (`<<'EOF'`)
instead. A quoted heredoc keeps Markdown backticks, `$VARS`, and command
substitutions literal while writing the local file, so the body stays inert until
the transport reads the file content.

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-text.XXXXXX")"
body_file="$run_dir/body.md"
cat > "$body_file" <<'EOF'
## Body

- Literal example: `echo "$EXAMPLE_VAR"` is not executed.
EOF
```

## Redaction and no-secrets rules

- **No secrets in GitLab text.** Never write credentials, API keys, auth headers,
  tokens, or sensitive payloads into a body that may be pasted to GitLab. Redact
  them before writing the text.
- **Redact before writing.** When a body may carry log output or external
  responses, strip secrets first; redact tokens, headers, and environment values
  at write time, not after submission.
- **Keep text files local and uncommitted.** Keep generated text files under
  temp/run directories and never commit review artifacts.
- **Diagnostics never print the body.** Caller and MCP validation diagnostics name the
  failing role and offset only; they do not echo the body, so a malformed or
  secret-bearing payload is never surfaced in logs.
