# GitLab Workflow Helpers

Optional shell helpers wrap accepted `/gitlab` fallback/helper snippets and read-only verification reports for repeatable parent-orchestrator, finisher, or verifier flows. They use `glab`, `git`, and Node.js for local JSON parsing. They do not replace MCP primary transport, the mandatory review gate, project policy, or role authority.

Mutating helpers are fallback implementations under the [GitLab Mutation Guard](../reference/mutation-guard.md); callers still own project binding, authority, caller identity, exact-SHA CI when relevant, safe-text validation when relevant, and post-mutation MCP re-read evidence.

## Helpers

| Helper | Source contract | Guard summary | Regression coverage |
| --- | --- | --- | --- |
| `gitlab-ci-watch.sh` | [`gitlab` Snippet: ci-watch-sha-pinned](../SKILL.md#snippet-ci-watch-sha-pinned) | Re-reads MR metadata, requires the MR head to match the reviewed SHA, and only passes green CI when the pipeline SHA matches that reviewed SHA. When the bound MR transitions to `merged` mid-watch and its observed head still equals the reviewed SHA, it emits the terminal `result=merged` (with the merge-commit SHA when readable, falling back to the squash-commit SHA) and exits 0; a merged MR whose head differs from the reviewed SHA fails closed as `head_changed` (exit 2) like every other head-mismatch poll. `unknown_mr_state` (exit 5) stays for genuinely unclassifiable non-merged states only. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-content-guard.sh` | [`gitlab` safe-text content-byte rule](../reference/safe-text.md) | Pure-local, no-network content-byte guard for a GitLab text body before MCP or fallback mutation. Reads from `--file <path>` or stdin, exits 0 when safe, and rejects NUL, non-whitespace C0 controls, and DEL with role + byte-offset diagnostics that never echo the body; tab, newline, and carriage return stay valid for Markdown. Makes no network call. | `../../tests/gitlab-content-guard.sh` |
| `gitlab-finish-authority.sh` | [`gitlab` Finish authority matrix](../reference/authority-matrix.md) inside canonical [Authority Verification](../reference/authority-verification.md) | Pure-local, no-network role × merge-authority × action gate. Exits 0 when the matrix permits the action and caller/author ids are present for audit/token-stability; otherwise fails closed with `reason=` in `invalid_user_id`, `authority_source_mismatch`, or `authority`. Builder callers only ever get `handoff`; same GitLab identity is not a finish blocker for a fresh gate-eligible reviewer. | `../../tests/gitlab-finish-authority.sh` |
| `gitlab-finish-mr.sh` | [`gitlab` Snippet: finish-mr-authority-aware](../SKILL.md#snippet-finish-mr-authority-aware) plus the [GitLab Mutation Guard](../reference/mutation-guard.md) / [Authority Verification](../reference/authority-verification.md) seams | Fallback/helper flow for the guard's SHA-bound finish profile: blocks stale heads, stale/red/missing CI, unknown MR state, missing or unknown merge authority, dirty worktree cleanup, and post-merge local cleanup before local default is fast-forwarded or an equivalent merged SHA is verified. Builder callers always get a handoff; they cannot approve, merge, or queue auto-merge. Human output records `via=glab-fallback`; YAML output records `transport: glab-fallback`. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-merge-watch.sh` | [`gitlab` Snippet: ci-watch-sha-pinned](../SKILL.md#snippet-ci-watch-sha-pinned) merge-completion sibling | SHA-pinned poll of a bound MR to a terminal merge state (`merged` / reviewed-SHA pipeline `failed`/`canceled` / head drift / timeout) read through the control-char-safe `safe_mr_json` projection (`gitlab-wrappers.sh`) — never a raw `glab … -F json \| jq` of the full MR body, so a Review Packet description carrying raw control characters fails closed (`result=blocked reason=invalid_control_character`, exit 3) instead of silently looping. Emits one parseable terminal line; only `result=merged` (with `merge_commit`, falling back to the squash-commit SHA) exits 0, and a non-merged terminal never reports success. Safe to run from a detached background bash loop via absolute-path invocation (no `skill://` at call time) and from foreground. References, not duplicates, the slim guard-read / `safe_mr_json` guidance (#286 lineage). | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-post-merge-snapshot.sh` | [`start-build` Post-merge verifier recipe](../../start-build/reference/post-merge-verifier.md) | Emits `post_merge_snapshot.kind=post-merge-snapshot` from read-only MR/issue/default-branch/source-branch checks, explicit reviewed/merge/squash containment, documented non-mutating validation, and pending items. It reports closure/cleanup pending instead of acting. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-wrappers.sh` | `draft-mr-create`, `mr-description-update`, `issue-note-create`, `mr-note-create`, `label-reconcile`, `safe-mr-json`, and `auto-merge-api-fallback` snippets plus the [GitLab Mutation Guard](../reference/mutation-guard.md) | Keeps fallback MR descriptions and issue/MR notes split and file-backed; delegates NUL/control-character validation to `gitlab-content-guard.sh` before `glab` submission; reconciles labels without replacement assumptions; validates decision-grade MR JSON; preserves SHA/CI/authority/project-binding guards for the known auto-merge 405 API fallback, which requests source-branch removal on merge (`--remove-source-branch` on the `glab` path, `should_remove_source_branch=true` on the API path). Callers still perform required post-mutation MCP re-reads before reporting success. | `../../tests/gitlab-workflow-helpers.sh` |
| `validate-closes-keyword.sh` | issue #295 (#293 recurrence); closing-pattern rationale owned by [`start-build/templates/review-packet.md`](../../start-build/templates/review-packet.md) | Pure-local, no-network shape linter for the GitLab auto-close keyword. Reads an MR description (stdin or file) plus `--issue-iid <iid>` and exits 0 only when a plain `<closing-keyword> #<iid>` (default `default_issue_closing_pattern` keyword set, case-insensitive) is present outside inline code spans and fenced code blocks and not only in a bolded/wrapped form; fails closed (exit 3, `CLOSES_KEYWORD result=invalid reason=no_plain_close ...`) when only `**Closes:** #N` / `` `Closes #N` `` / no eligible reference exists, and exit 64 on usage/argument errors. Presence/shape only; never contacts GitLab. | `../../tests/closes-keyword-lint.sh` |
| `validate-finish-result.sh` | [`finish_result` schema](../reference/finish-result-schema.json) | Pure-local, no-network validator for a `finish_result` JSON object (stdin or file). Reads the schema as the single source of truth for required fields and enums, including transport evidence (`mcp`, `glab-fallback`, `n/a`), exits 0 only when every required field is present with a correctly enumerated/typed value, and fails closed with a single `FINISH_RESULT result=invalid reason=...` line on bad JSON (exit 5), or missing field / enum / type / pattern mismatch (exit 3). | `../../tests/finish-result-schema.sh` |

Tests in `../../tests/gitlab-workflow-helpers.sh` use fake `glab` and `git` binaries, so the regression suite performs no live GitLab mutation. The snapshot coverage verifies merged, closure-pending, branch-cleanup-pending, retained-by-policy/unknown, stale/missing containment, and validation not-run cases without approving, merging, queueing auto-merge, force-closing issues, deleting branches, releasing, deploying, or mutating product/runtime systems. The wrapper coverage also verifies fake MR description create/update, issue/MR notes, label updates, MR JSON, auto-merge fallback paths, and delegation to the shared content guard without changing live labels or MRs; malformed packet diagnostics are asserted without logging the submitted body.

Coverage in `../../tests/gitlab-split-snippets.sh` verifies `/gitlab` keeps stable snippet names while pointing long helper bodies here and to script sources. Coverage in `../../tests/gitlab-mcp-first-workflows.sh` verifies top-level workflow docs/prompts stay MCP-first while allowing these guarded fallback/helper paths.

## Resolving `skill://` URIs to filesystem paths

`skill://` URIs are runtime token references, not filesystem paths. Embedding a
bare `skill://` URI in a `bash` eval context (e.g., `source skill://gitlab/scripts/gitlab-wrappers.sh`)
fails because the shell has no resolver — the runtime expands them only when they
appear as string arguments to supported tool calls (Read, Bash with quoted content,
etc.). A mid-delivery sourcing failure caused by this was the trigger for this
recipe (claude-mem obs 4875).

### Resolution recipe

Derive the `skill://` root from the **invoked skill's own installed location**.
Never hardcode `~/.claude/skills` or `~/.omp/agent/skills`; both are valid
install targets and the installed skill directory name may differ from the repo
directory name (e.g. `gitlab-local` vs `gitlab` during a rename window).

```bash
# --- skill:// resolution recipe (runtime-agnostic) ---
#
# Step 1: Locate this skill's own SKILL.md via a Read tool call
#         (the runtime expands skill:// there) and capture the resolved path.
#         Example: Read("skill://gitlab/SKILL.md") resolves to an absolute path
#         such as /home/user/.omp/agent/skills/gitlab-local/SKILL.md
#         or      /home/user/.claude/skills/gitlab/SKILL.md
#
# Step 2: Strip the SKILL.md filename to get the skill root.
#         SKILL_ROOT="$(dirname "<resolved-path-from-step-1>")"
#         # e.g. /home/user/.claude/skills/gitlab
#
# Step 3: Reference any script relative to that root.
#         GITLAB_WRAPPERS="${SKILL_ROOT}/scripts/gitlab-wrappers.sh"
#         source "${GITLAB_WRAPPERS}"
#         # or: bash "${SKILL_ROOT}/scripts/gitlab-ci-watch.sh" --mr-iid ...
```

**Concrete example** — the `source .../gitlab-wrappers.sh` case that failed:

```bash
# In the workflow skill doc the snippet says:
#   gitlab_wrappers_script="skill://gitlab/scripts/gitlab-wrappers.sh"
#   "$gitlab_wrappers_script" draft_mr_create ...
#
# At agent runtime, translate that URI before the bash command runs:
#
# 1. Use a Read tool call to resolve skill://gitlab/SKILL.md.
#    Suppose the resolved path is:
#      /home/runner/.claude/skills/gitlab/SKILL.md
#
# 2. Derive the root:
#    SKILL_ROOT="/home/runner/.claude/skills/gitlab"
#
# 3. Use the absolute path:
#    GITLAB_WRAPPERS="${SKILL_ROOT}/scripts/gitlab-wrappers.sh"
#    "${GITLAB_WRAPPERS}" draft_mr_create \
#      --repo "$repo_url" \
#      --target-branch "$default_branch" \
#      --source-branch "$source_branch" \
#      --title "$title" \
#      --description-file "$description_file"
```

This pattern works on any runtime because:

- The skill root is derived at runtime from an actual Read resolution, not a
  hardcoded path.
- The installed directory name is whatever the runtime installed it as; `dirname`
  strips only the `SKILL.md` filename.
- No assumption is made about the user's home directory layout or the skill repo's
  directory name.

For helper script URIs that appear in workflow skill docs (e.g.,
`skill://gitlab/scripts/gitlab-ci-watch.sh`), apply the same recipe: resolve the
skill root once, then substitute the path component from the URI.

## When to prefer MCP primary snippets

Use MCP primary tools from [`../reference/snippet-transports.md`](../reference/snippet-transports.md) for normal GitLab API actions.

Use these fallback/helper scripts when:

- MCP tooling is unavailable or the documented MCP merge/list gap is hit;
- the local `glab` version or GitLab response shape differs and help-first troubleshooting is needed;
- the flow needs a human waiver, project-specific policy, or variant not encoded in generic MCP paths;
- you are diagnosing GitLab behavior and need each fallback command visible step by step;
- you are updating accepted workflow behavior in `gitlab` itself;
- the caller lacks clear approval/merge authority and needs a handoff/blocker result instead of an action.

Use helpers only when the accepted snippet behavior already fits and you want a repeatable fallback command with fail-closed guardrails.
