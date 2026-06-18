# GitLab safe-text reference

Transport-agnostic safety rules for any text body submitted to GitLab — MR/issue
descriptions and notes — regardless of whether the body reaches GitLab through a
file-backed `glab` wrapper, an MCP `body`/`description` string, or another
transport. This reference owns two durable concerns:

1. The **content-byte rule** that every GitLab write must satisfy.
2. The **shell-safety guidance** (inline-heredoc command-substitution hazard,
   redaction rule, no-secrets rule) migrated here from `multiline-text.md` so the
   knowledge survives that file's later deletion.

The [`GitLab Mutation Guard`](mutation-guard.md) calls this the **Safe GitLab Text** phase; a content-byte failure blocks both MCP and fallback before any body-bearing GitLab mutation.

## Content-byte rule

A GitLab text body is byte-safe only when it contains no NUL byte, no
non-whitespace C0 control character, and no DEL (`0x7f`). Tab (`0x09`), newline
(`0x0a`), and carriage return (`0x0d`) stay valid because Markdown bodies use
them. Reject the body before any GitLab write when it violates this rule.

The MCP validator `validate_gitlab_text` owns the active workflow contract for this rule. Body-bearing MCP mutation helpers (`safe_update_merge_request_description`, `safe_create_merge_request_note`, `safe_create_issue_note`) apply the same rule before sending text to GitLab. Historical local guards may exist for fallback/regression fixtures, but active workflow docs must name the MCP validator/tool contract.

`validate_gitlab_text` accepts a body plus body role, returns success when body is safe, and fails closed on NUL, non-whitespace C0 controls, or DEL. Diagnostics name the role and offending byte offset and **never print body**, so malformed secret-bearing payload is not echoed back.

```text
validate_gitlab_text(role="merge request description", body=body)
# PASS: no NUL, non-whitespace C0 controls, or DEL
# FAIL: role + byte offset only; body is not printed
```

`MCP safe GitLab text tools` delegates file-backed fallback
validation to `validate_gitlab_text` before `glab mr create`, `glab mr
update`, and note submission. MCP callers that pass a `body` or `description`
string must run `validate_gitlab_text` (or the exact same byte rule in
process) before the MCP mutation, so every GitLab text mutation shares the same
role/offset-only diagnostic contract.

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
- **Diagnostics never print the body.** Guard and wrapper diagnostics name the
  failing role and byte offset only; they do not echo the body, so a malformed or
  secret-bearing payload is never surfaced in logs.
