# GitLab multiline text reference

This reference owns the detailed file-backed text pattern for `/gitlab`; [`SKILL.md`](../SKILL.md#safe-multiline-gitlab-text) keeps the compatibility heading and safety summary.

## Safe multiline GitLab text

Draft multiline notes/descriptions in temp/run-dir files with quoted heredocs. A quoted `<<'EOF'` keeps Markdown backticks, `$VARS`, and command substitutions literal. Read the file into MCP `body`/`description` only after `validate_gitlab_text` passes; the safe mutation tools embed the same validation. Eligible guarded `glab` fallback may consume the same file.

The validator rejects NUL, non-whitespace C0 controls, and DEL; tab, newline, and carriage return remain valid Markdown. Diagnostics do not print secrets or the malformed packet body; they identify only the text role and failing byte offset.

Keep generated text under temp/run directories, never commit review artifacts, and redact secrets before drafting GitLab-bound text. Keep only the intended auto-close trailer in plain closing-keyword form (for example `Closes #341`). For an issue the MR must **not** close, write `issue 410`, `group/project#410`, or `` `#410` `` rather than a bare `#410` in non-closing prose.

## Canonical file-backed pattern

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-text.XXXXXX")"
text_file="$run_dir/body.md"
text_role="description"
cat > "$text_file" <<'EOF'
## Review Packet

- Reviewed SHA: `abc123`
- Literal example: `echo "$EXAMPLE_VAR"` not executed.
EOF

```

The caller reads the complete file, preserving trailing newlines, into
`text_body`, then invokes the MCP validator (not a shell command):

```text
validate_gitlab_text(role="description", content=text_body)
```

Choose the role, payload field, and safe mutation for the destination:

| Destination | `text_role` | Payload / mutation |
| --- | --- | --- |
| MR note | `note` | `body`; `safe_create_merge_request_note(project=project_path, merge_request_iid=mr_iid, body=text_body)` creates a plain top-level non-resolvable note |
| Issue note | `note` | `body`; `safe_create_issue_note(..., body=text_body)` |
| MR description | `description` | `description`; `create_merge_request(..., description=text_body, draft=true)` or `safe_update_merge_request_description(..., description=text_body)` |

Re-read a created note before treating it as durable Review Report evidence. Compare exact-note content (or losslessly recovered chunks) with the authored source; canonical stored-body digest equality alone does not establish source equality. Re-read an MR after creation/update before trusting its description or state.

## Shell-safety owner

[`safe-text.md` §Inline heredoc command-substitution hazard](safe-text.md#inline-heredoc-command-substitution-hazard) owns the forbidden inline-heredoc example and why backticks/`$()` may execute in the parent shell. Use the quoted, file-backed pattern above instead.
