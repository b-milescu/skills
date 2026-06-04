# GitLab safe-text reference

Transport-agnostic safety rules for any text body submitted to GitLab — MR/issue
descriptions and notes — regardless of whether the body reaches GitLab through a
file-backed `glab` wrapper, an MCP `body`/`description` string, or another
transport. This reference owns two durable concerns:

1. The **content-byte rule** that every GitLab write must satisfy.
2. The **shell-safety guidance** (inline-heredoc command-substitution hazard,
   redaction rule, no-secrets rule) migrated here from `multiline-text.md` so the
   knowledge survives that file's later deletion.

## Content-byte rule

A GitLab text body is byte-safe only when it contains no NUL byte, no
non-whitespace C0 control character, and no DEL (`0x7f`). Tab (`0x09`), newline
(`0x0a`), and carriage return (`0x0d`) stay valid because Markdown bodies use
them. Reject the body before any GitLab write when it violates this rule.

The standalone guard `gitlab-local/scripts/gitlab-content-guard.sh` enforces
exactly this rule. It reads a body from `--file <path>` or stdin, exits 0 when the
body is safe, and exits non-zero when it finds a NUL byte, a non-whitespace C0
control, or DEL. Diagnostics name the failing role and the offending byte offset
and **never print the body**, so a malformed or secret-bearing payload is not
echoed back. The guard makes no network call.

```bash
# stdin
printf '%s' "$body" | gitlab-local/scripts/gitlab-content-guard.sh --role description

# file-backed
gitlab-local/scripts/gitlab-content-guard.sh --file "$description_file" --role description
```

The same byte rule lives inside `gitlab-local/scripts/gitlab-wrappers.sh`
`validate_text_file`, which runs before file-backed `glab mr create`,
`glab mr update`, and note submission; `gitlab-content-guard.sh` is the slim
standalone extraction for transports that do not go through those wrappers.

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
