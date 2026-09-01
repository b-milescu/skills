# gitlab-mcp contract verification reference

Reference for the MCP-first GitLab transport used by `/gitlab` and by `/plan-to-issues` after `/forge` binds GitLab. MCP is primary for normal API actions; guarded `glab` fallback is limited to known gaps, helper-only safe-text paths, and troubleshooting.

Evidence here is read-only or schema-level unless marked `live-smoke`; do not infer unobserved mutation behavior. Fallback syntax stays in [`gitlab/SKILL.md`](../SKILL.md), per-snippet contracts in [`snippet-transports.md`](snippet-transports.md), and mutation ordering in the [GitLab Mutation Guard](mutation-guard.md).

## Verification status legend

| Status | Meaning |
| --- | --- |
| `live-read` | Confirmed by a read-only call against the real server. |
| `live-smoke` | Confirmed by maintainer smoke testing against normal fixtures. |
| `schema` | Confirmed from the tool input/output JSON schema. |
| `sandbox-procedure` | Deferred sandbox/fake-harness procedure, not a live result. |

## 1. `confirm:true` enforcement

**Fact (`schema`).** `approve_merge_request` and `merge_merge_request` require `confirm` constrained to `true`. Omitting it or passing `false` fails client-side schema validation before any network request. Inspect `tools/list` or the published tool definition to verify `required` and the property's constraint.

**Workflow consequence.** Pass `confirm: true` explicitly. Its absence is a programming bug, not a retryable GitLab/API failure.

## 2. Normal-path MCP parity

**Fact (`live-smoke`, issue #210).** MCP read/list/comment/diff/approval/pipeline/branch/file endpoints matched `glab`/GitLab API behavior for normal fixtures. Use MCP first for ordinary issue/MR/review delivery; reserve `glab` for a named fallback, helper, or troubleshooting condition.

## 3. `update_merge_request` atomicity

**Designed contract.**

- Sending `description` and `draft:false` together sets both in one server-side update.
- Sending only `draft:false` preserves the description. Omit `description`; never send an empty placeholder merely to toggle draft state.

**Verification.** The independent optional fields are `schema`-verified; preservation/atomicity remains a `sandbox-procedure`:

1. Record `description` and `draft` with `get_merge_request`.
2. Update both fields, re-read, and assert both match.
3. On a fresh draft MR with a known description, send `draft:false` without `description`, then assert the body is unchanged.
4. An emptied, partial, or missing body blocks the ready path.

## 4. Known MCP gaps

### Merge robustness / error normalization

**Fact (`live-smoke`, issue #210).** One fixture returned `Branch cannot be merged` from `merge_merge_request` while the equivalent SHA-bound `glab mr merge --sha ...` succeeded.

The [GitLab Mutation Guard](mutation-guard.md) owns the only allowed `mcp_merge_robustness_gap` fallback, its full preconditions, single-action limit, MCP post-read, and `via=glab-fallback` evidence. This gap never excuses a failed non-transport guard.

### List pagination limitations

**Fact (`live-smoke`/tool-surface observation, issue #210).** Exposed `list_*` MCP tools do not show reliable pagination controls to the agent. Broad calls can under-report.

Never treat a broad single `list_*` page as exhaustive. Treat this as `mcp_pagination_gap` only when exhaustive selection is required: narrow to a bounded candidate set, re-read each candidate with `get_issue`/`get_merge_request`, or use guarded fallback to find candidates. Lists remain candidate data; a single-record read decides before mutation.

## 5. Idempotency and partial failures

After every mutation, immediately re-read the applicable record through MCP and re-check the expected SHA before trusting local state. Report `via=mcp` or, for an eligible guarded fallback, `via=glab-fallback`.

The [Mutation Guard outputs](mutation-guard.md#outputs) and its schema own blocker/gap tokens and post-read classifications, including `already_merged`, `stale_head`, and `merge_blocked`. Classify before retrying: `already_merged` is success-equivalent; stale or blocked state fails closed. Any retry loop has a small fixed bound and reports its last classification.

## 6. Project-path and default-branch validation

`get_project("agents/skills")` was `live-read` verified to return the canonical path, default branch, and HTTPS/SSH repository URLs. The Mutation Guard's [Project binding](mutation-guard.md#ordered-guard-sequence) phase owns the operative preflight: derive the project from `origin`, compare it with `get_project().pathWithNamespace`, resolve `defaultBranch` from the server, and stop on discrepancy. Preserve local Git worktree/ref checks; MCP does not replace them.

## Cross-references

- Stable snippet contracts: [`snippet-transports.md`](snippet-transports.md).
- Mutation Guard and schema: [`mutation-guard.md`](mutation-guard.md), [`mutation-guard.schema.json`](mutation-guard.schema.json).
- Safe text/content-byte rule: [`safe-text.md`](safe-text.md).
- Guarded fallback help-first discipline: [`gitlab/SKILL.md`](../SKILL.md#guarded-glab-fallback-and-help-first-rule).
