# gitlab-mcp contract verification reference

Reference for the MCP-first GitLab workflow transport used by `/gitlab` and, when `/forge` binds GitLab, by `/gitlab-to-issues`. MCP is the primary path for normal GitLab API actions; guarded `glab` fallback remains documented for known gaps, helper-only safe-text paths, and troubleshooting.

Scope discipline for this reference:

- **Evidence is read-only / schema-level unless explicitly marked as smoke-test evidence.** Do not infer unobserved mutation behavior from this doc.
- Each area states the fact, verification method, and any deferred procedure needed for sandbox/fake-harness confirmation.
- Fallback command syntax and flag ownership remain in [`gitlab/SKILL.md`](../SKILL.md); per-snippet MCP/fallback contracts live in [`snippet-transports.md`](snippet-transports.md), and mutating-action ordering lives in the [GitLab Mutation Guard](mutation-guard.md).

## Verification status legend

| Status | Meaning |
| --- | --- |
| `live-read` | Confirmed by a read-only call against the real server (no mutation). |
| `live-smoke` | Confirmed by maintainer smoke testing against normal fixture records. |
| `schema` | Confirmed from tool input/output JSON schema, no network mutation. |
| `sandbox-procedure` | Not confirmed in this environment; recorded as a deferred procedure, not asserted as a live result. |

## 1. `confirm:true` enforcement (schema-level)

**Fact.** The destructive tools `approve_merge_request` and `merge_merge_request` declare `confirm` in their input schema as a required property constrained to `const: true` (or `enum: [true]`). A call that omits `confirm`, or sends `confirm:false`, fails client-side JSON-schema validation before any network request is issued.

**Verification method.** `schema` — inspect the tool input schema (`tools/list` MCP listing or the published tool definition). Confirm for each destructive tool that `required` contains `confirm` and that the property permits only `true`.

**Workflow consequence.** Agent code must pass `confirm: true` explicitly on every `approve_merge_request` / `merge_merge_request` call. Missing `confirm` is a programming bug, not a retryable GitLab/API failure.

## 2. Normal-path MCP parity smoke findings

**Fact.** Maintainer smoke testing found the MCP read/list/comment/diff/approval/pipeline/branch/file endpoints matched `glab`/GitLab API behavior for normal fixtures. This supports MCP as the primary transport for issue pickup, MR pickup, notes, diffs, approval confirmation/action, pipeline reads, branch checks, and file reads in ordinary delivery flows.

**Verification method.** `live-smoke` — cited in issue #210. This doc records the finding; it does not replay live mutations.

**Workflow consequence.** `/gitlab` snippets should name MCP primary tools first and reserve `glab` for explicit fallback/helper/troubleshooting conditions. Normal issue/MR/review delivery should not instruct unconditional primary `glab` use.

## 3. `update_merge_request` atomicity (designed contract + test procedure)

**Designed contract.**

- A single `update_merge_request` call that sends both `description` and `draft:false` toggles the MR to ready and sets the body in one server-side update.
- A call that sends `draft:false` alone preserves the existing description. Omit `description` to leave it unchanged; never send an empty placeholder body merely to toggle draft state.

**Verification method.** `schema` for independent optional `description`/`draft` fields, plus `sandbox-procedure` for live atomicity/preservation behavior.

**Sandbox test procedure.**

1. Read the current state with `get_merge_request`; record `description` and `draft`.
2. Call `update_merge_request` with `description: <body1>` and `draft: false`; re-read `get_merge_request` and assert both fields match.
3. On a fresh draft MR with known `description`, call `update_merge_request` with `draft: false` and no `description`; re-read and assert the body is unchanged.
4. Any emptied, partially-applied, or missing body blocks the ready-toggle path.

## 4. Known MCP gaps

### Merge robustness / error normalization

**Fact.** One observed fixture had `merge_merge_request` return a robustness/error-normalization failure (`Branch cannot be merged`) where the equivalent SHA-bound `glab mr merge --sha ...` succeeded.

**Verification method.** `live-smoke` finding from issue #210; exact fixture details are not copied here.

**Workflow consequence.** Merge fallback is allowed only as a guarded `mcp_merge_robustness_gap` exception in the [GitLab Mutation Guard](mutation-guard.md). Before fallback, re-read the MR through MCP, verify current head SHA equals the reviewed SHA, verify exact-SHA CI and merge authority/source, verify caller identity/token stability and context-firewall eligibility, run help-first for the exact fallback command, execute exactly one fallback action, re-read through MCP, and record `via=glab-fallback`. Do not fallback on stale head, red/missing/stale CI, missing authority, permission uncertainty, identity drift, content-byte failure, or same-session review/finish risk.

### List pagination limitations

**Fact.** Exposed `list_*` MCP tools do not show reliable pagination controls to the agent. Broad list calls can under-report when more records exist than the returned page.

**Verification method.** `live-smoke`/tool-surface observation cited in issue #210.

**Workflow consequence.** Never treat a broad single `list_*` page as exhaustive. Treat this as `mcp_pagination_gap` when it blocks exhaustive selection. For decision-grade selection, narrow the query enough to identify a bounded candidate set, re-read each candidate with `get_issue`/`get_merge_request`, or use guarded fallback for exhaustive selection. List data is candidate data; single-record reads decide before any Mutation Guard action can mutate.

## 5. Idempotency and partial-failure contract

**Designed rules.**

- **Re-read after every mutation.** After any mutating MCP tool call (`update_merge_request`, `approve_merge_request`, `merge_merge_request`, notes, label/assignee changes), immediately re-read through MCP (`get_merge_request`, `get_issue`, approval state, or notes/discussions as applicable) and re-check the SHA pin before trusting local state.
- **SHA-pin re-check.** Compare the re-read head SHA against the reviewed/expected SHA. A mismatch means the head moved under the operation and the action must not be assumed applied to the intended commit.
- **Transport evidence.** Report `via=mcp` for successful MCP actions and `via=glab-fallback` for guarded fallback actions.
- **Mutation Guard evidence.** The canonical guard schema (`skill://gitlab/reference/mutation-guard.schema.json`) owns shared blocker and gap tokens including `mcp_unavailable`, `mcp_merge_robustness_gap`, and `mcp_pagination_gap`.

**Conflict classification.** When a mutation does not produce the expected state, classify from the re-read before retrying:

| Classification | Detected by | Meaning / action |
| --- | --- | --- |
| `already_merged` | Re-read shows MR state `merged` or a merge/squash commit. | Treat as success-equivalent; do not retry merge. |
| `stale_head` | Re-read head SHA differs from pinned/expected SHA. | Fail closed; re-evaluate against the new SHA. |
| `merge_blocked` | Re-read MR state is not mergeable/open and no merge commit is present. | Fail closed; surface for parent/human decision. |

**Retry guard.** A retry loop must cap attempts at a small fixed bound, then fail closed and report the last classification. `already_merged` short-circuits; `stale_head` and `merge_blocked` exit to a blocker report.

## 6. Project-path and default-branch validation

**Fact (live-read).** `get_project` for `agents/skills` returns, among other fields:

- `pathWithNamespace: "agents/skills"`
- `defaultBranch: "main"`
- `httpUrlToRepo: "https://gitlab.example.com/agents/skills.git"`
- `sshUrlToRepo: "git@gitlab.example.com:agents/skills.git"`

**Verification method.** `live-read` — confirmed read-only against the real server.

**Validation rule.**

1. Derive the candidate project path from `git remote get-url origin` (strip scheme/host and trailing `.git`; for SSH, parse `git@<host>:group/project.git`).
2. Call `get_project(<candidate-path>)` and compare `pathWithNamespace` to the candidate.
3. If `pathWithNamespace` differs, trust the server and stop to surface the discrepancy.
4. Resolve the default branch from `get_project().defaultBranch`; never assume `main`/`master` or stale `origin/HEAD`.
5. Preserve local `git` worktree/ref safety for branch creation, fetch, checkout, `rev-parse`, and `ls-remote`; MCP does not replace those local checks.

## Cross-references

- Stable snippet transport contracts: [`snippet-transports.md`](snippet-transports.md).
- GitLab Mutation Guard seam and schema: [`mutation-guard.md`](mutation-guard.md), [`mutation-guard.schema.json`](mutation-guard.schema.json).
- Safe text/content-byte rule for MCP and fallback bodies: [`safe-text.md`](safe-text.md).
- Guarded fallback help-first discipline: [`gitlab/SKILL.md`](../SKILL.md#guarded-glab-fallback-and-help-first-rule).
