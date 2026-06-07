# GitLab Workflow Helpers

Optional shell helpers wrap accepted `/gitlab-local` fallback/helper snippets and read-only verification reports for repeatable parent-orchestrator, finisher, or verifier flows. They use `glab`, `git`, and Node.js for local JSON parsing. They do not replace MCP primary transport, the mandatory review gate, project policy, or role authority.

## Helpers

| Helper | Source contract | Guard summary | Regression coverage |
| --- | --- | --- | --- |
| `gitlab-ci-watch.sh` | [`gitlab-local` Snippet: ci-watch-sha-pinned](../SKILL.md#snippet-ci-watch-sha-pinned) | Re-reads MR metadata, requires the MR head to match the reviewed SHA, and only passes green CI when the pipeline SHA matches that reviewed SHA. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-content-guard.sh` | [`gitlab-local` safe-text content-byte rule](../reference/safe-text.md) | Pure-local, no-network content-byte guard for a GitLab text body before MCP or fallback mutation. Reads from `--file <path>` or stdin, exits 0 when safe, and rejects NUL, non-whitespace C0 controls, and DEL with role + byte-offset diagnostics that never echo the body; tab, newline, and carriage return stay valid for Markdown. Makes no network call. | `../../tests/gitlab-content-guard.sh` |
| `gitlab-finish-authority.sh` | [`gitlab-local` Finish authority matrix](../reference/authority-matrix.md) | Pure-local, no-network role × merge-authority × action gate. Exits 0 when the matrix permits the action and caller/author ids are present for audit/token-stability; otherwise fails closed with `reason=` in `invalid_user_id`, `authority_source_mismatch`, or `authority`. Builder callers only ever get `handoff`; same GitLab identity is not a finish blocker for a fresh gate-eligible reviewer. | `../../tests/gitlab-finish-authority.sh` |
| `gitlab-finish-mr.sh` | [`gitlab-local` Snippet: finish-mr-authority-aware](../SKILL.md#snippet-finish-mr-authority-aware) | Fallback/helper flow that blocks stale heads, stale/red/missing CI, unknown MR state, missing or unknown merge authority, dirty worktree cleanup, and post-merge local cleanup before local default is fast-forwarded or an equivalent merged SHA is verified. Builder callers always get a handoff; they cannot approve, merge, or queue auto-merge. Human output records `via=glab-fallback`; YAML output records `transport: glab-fallback`. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-post-merge-snapshot.sh` | [`start-build` Post-merge verifier recipe](../../start-build/reference/post-merge-verifier.md) | Emits `post_merge_snapshot.kind=post-merge-snapshot` from read-only MR/issue/default-branch/source-branch checks, explicit reviewed/merge/squash containment, documented non-mutating validation, and pending items. It reports closure/cleanup pending instead of acting. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-wrappers.sh` | `draft-mr-create`, `mr-description-update`, `issue-note-create`, `mr-note-create`, `label-reconcile`, `safe-mr-json`, and `auto-merge-api-fallback` snippets | Keeps fallback MR descriptions and issue/MR notes split and file-backed; delegates NUL/control-character validation to `gitlab-content-guard.sh` before `glab` submission; reconciles labels without replacement assumptions; validates decision-grade MR JSON; preserves SHA/CI/authority/project-binding guards for the known auto-merge 405 API fallback. | `../../tests/gitlab-workflow-helpers.sh` |
| `validate-finish-result.sh` | [`finish_result` schema](../reference/finish-result-schema.json) | Pure-local, no-network validator for a `finish_result` JSON object (stdin or file). Reads the schema as the single source of truth for required fields and enums, including transport evidence (`mcp`, `glab-fallback`, `n/a`), exits 0 only when every required field is present with a correctly enumerated/typed value, and fails closed with a single `FINISH_RESULT result=invalid reason=...` line on bad JSON (exit 5), or missing field / enum / type / pattern mismatch (exit 3). | `../../tests/finish-result-schema.sh` |

Tests in `../../tests/gitlab-workflow-helpers.sh` use fake `glab` and `git` binaries, so the regression suite performs no live GitLab mutation. The snapshot coverage verifies merged, closure-pending, branch-cleanup-pending, retained-by-policy/unknown, stale/missing containment, and validation not-run cases without approving, merging, queueing auto-merge, force-closing issues, deleting branches, releasing, deploying, or mutating product/runtime systems. The wrapper coverage also verifies fake MR description create/update, issue/MR notes, label updates, MR JSON, auto-merge fallback paths, and delegation to the shared content guard without changing live labels or MRs; malformed packet diagnostics are asserted without logging the submitted body.

Coverage in `../../tests/gitlab-local-split-snippets.sh` verifies `/gitlab-local` keeps stable snippet names while pointing long helper bodies here and to script sources. Coverage in `../../tests/gitlab-mcp-first-workflows.sh` verifies top-level workflow docs/prompts stay MCP-first while allowing these guarded fallback/helper paths.

## When to prefer MCP primary snippets

Use MCP primary tools from [`../reference/snippet-transports.md`](../reference/snippet-transports.md) for normal GitLab API actions.

Use these fallback/helper scripts when:

- MCP tooling is unavailable or the documented MCP merge/list gap is hit;
- the local `glab` version or GitLab response shape differs and help-first troubleshooting is needed;
- the flow needs a human waiver, project-specific policy, or variant not encoded in generic MCP paths;
- you are diagnosing GitLab behavior and need each fallback command visible step by step;
- you are updating accepted workflow behavior in `gitlab-local` itself;
- the caller lacks clear approval/merge authority and needs a handoff/blocker result instead of an action.

Use helpers only when the accepted snippet behavior already fits and you want a repeatable fallback command with fail-closed guardrails.
