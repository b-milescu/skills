---
name: gitlab
description: >-
  MCP-first GitLab transport reference for local/self-hosted GitLab: gitlab-mcp
  first, guarded help-first glab fallback. Use when GitLab-backed workflows need
  issue/MR/CI reads, issue/MR mutations, Mutation Guard rules, safe multiline
  text handling, or glab fallback syntax.
---

# GitLab transport reference

Use from the GitLab-backed worktree, in this order:

1. **MCP first.** Use the tools in [`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) and [`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md).
2. **Guarded `glab` fallback second.** Only for a named fallback/helper/troubleshooting condition, after applicable binding, SHA, CI, authority, and identity checks.
3. **Local `git` remains local.** Keep worktree, branch, fetch, and ref checks in `git`.

Known MCP gaps are owned by
[`mutation-guard.md` §First-class MCP gap states](skill://gitlab/reference/mutation-guard.md#first-class-mcp-gap-states).
Bounded metadata/body-read rules live in
[`bounded-reads.md`](skill://gitlab/reference/bounded-reads.md).

## Guarded glab fallback and help-first rule

Before any flagged fallback `glab` command, run exact command help and verify every flag with `glab <area> <verb> --help`.

Do not invent flags from memory or other CLIs. If help conflicts with this skill, use help and note skill drift.

Project hooks may specialize policy but not exact-candidate Gate Receipt, reviewed-SHA binding, explicit authority, independent review, role boundaries, MCP-first transport correctness plus help-first `glab` fallback correctness, or live help verification. CI is advisory evidence whose status is attributed only with exact-SHA binding. Shared delivery blocks retain GitLab terms: `issue`, `MR`, `pipeline`, `source branch`, `target branch`, and `SHA`.

### Per-run help cache

Help-first remains mandatory for fallback `glab`. The run-dir help cache — kept in a temp/run artifact directory and never committed — records the exact `glab <command> --help` output with verification status for this run and context. Refresh the cache whenever the command, `glab` version, or repo context changes.

## Important fallback/local pitfalls

- Issue `labels` are strings: use `.labels`, not `.labels[].name`.
- `glab ci status --mr` is unreliable; prefer MCP `get_merge_request`/`list_pipelines` exact-SHA reads, or fallback branch CI / MR `.pipeline` only as contract allows.
- `glab mr list -F json` is candidate data; use MCP `get_merge_request` or fallback `glab mr view <id> -F json` for decision-grade SHA/pipeline/mergeability.
- Use `-R "$repo_url"` when fallback repo/host inference might be wrong.
- Use file-backed long descriptions/messages; [`safe-text.md`](skill://gitlab/reference/safe-text.md) owns the caller steps and the never-print-bodies rule.

## Safe multiline GitLab text

Validate every MR/issue body before mutation with `validate_gitlab_text` or a safe mutation tool that embeds it. [`safe-text.md`](skill://gitlab/reference/safe-text.md) owns the byte rule and the role/offset-only diagnostics.

Draft long text in temp/run-dir files with quoted heredocs; [`safe-text.md` §Inline heredoc command-substitution hazard](skill://gitlab/reference/safe-text.md#inline-heredoc-command-substitution-hazard) owns the file-backed pattern.

GitLab strips exactly one trailing newline from a published note or description body. Compute expected digests and byte counts over that stripped form. A one-byte difference of exactly that shape is GitLab's normalisation — never a failed write and never a reason to create a second note. This does not weaken authored-source readback equality in [`safe-text.md`](skill://gitlab/reference/safe-text.md).

## Issue publication

Use `create_issue` with required native arguments `project`,
`expected_project_id`, `expected_user_id`, and `title`, plus the intended
publication fields. The bound MCP connection owns the API destination.

Before publication, compare a fresh successful `get_project` response's
canonical project/clone metadata with the independently intended repository
from preflight. Bind `expected_project_id` to that verified project and
`expected_user_id` through a fresh authenticated `get_current_user` read.
Missing/conflicting repository evidence, a wrong repository, or identity drift
blocks publication. Instance-local project/user IDs alone are not cross-instance
identity proof. Use exact existing label names and preserve every submitted
field, including authored Markdown.

If the mounted `create_issue` schema still requires `expected_api_url`, stop
before POST with a server/client contract-version blocker; resume only with the
URL-free schema.

The native tool validates bindings/text, POSTs once, and compares submitted
intent against raw GET. Classify its body-free receipt before continuing:

| Outcome | Caller response |
|---|---|
| `verified_created` | Record the verified IID/locator and submitted-field evidence. |
| `not_created` | No creation established; report the failure and resolve its prerequisite before any separately authorized new attempt. |
| `creation_unknown` | Do not repeat POST. Reconcile with bounded native reads; ambiguous or absent matches require a human decision. |
| `created_unverified` | Preserve the known IID; recover with GET-only reads and compare every submitted field, recovering authored body losslessly. |

Never automatically repeat creation, including after timeout or failed
readback. A known IID always takes GET-only recovery; without one, use bounded
reconciliation, not a guessed IID. Later label reconciliation is a separately
authorized mutation, never silent repair of failed publication. Other actions
retain their own verified recovery contracts.

## Three issue-closure oracles

Keep three distinct oracles:

- `validate_closes_keyword` answers whether authored syntax closes the target; it cannot prove nothing else closes.
- `closes_issues` previews unintended closures but may include code-spanned pairs GitLab will not act on. Keyword/reference non-adjacency satisfies both checks.
- Post-merge issue state is authoritative. Verification is read-only: report `issue_closure_pending` rather than force-closing an open target.

## GitLab Mutation Guard

Every GitLab mutation uses the ordered **GitLab Mutation Guard** in [`mutation-guard.md`](skill://gitlab/reference/mutation-guard.md) and its machine schema at `skill://gitlab/reference/mutation-guard.schema.json`.

## Canonical snippets

Snippet names and contracts are stable API. [`snippet-metadata.json`](skill://gitlab/reference/snippet-metadata.json) is the machine source of truth; [`snippet-transports.md`](skill://gitlab/reference/snippet-transports.md) is its synchronized table. This skill owns transport order, help-first fallback, flag drift, and the snippet index below.

Approval, direct merge, auto-merge queueing, and approval confirmation are separate actions. Choose exactly one action snippet for the authority you have. Never run a combined approval/merge block or paste multiple action snippets as one executable sequence. Before any approval/merge action or fallback, run the [GitLab Mutation Guard](#gitlab-mutation-guard) above (canonical owner: [`skill://gitlab/reference/mutation-guard.md`](skill://gitlab/reference/mutation-guard.md)); it stops on stale head, missing/stale Gate Receipt, missing authority, permission uncertainty, identity drift, same-session/self-finish risk, or fallback-ineligible states. CI status is advisory.

Bodies live in three phase-grouped files; read only the group your phase needs. Grouping rationale: [ADR-0002](../docs/adr/0002-phase-grouped-gitlab-snippet-disclosure.md).

- `read-evidence` — [`snippets-read-evidence.md`](skill://gitlab/reference/snippets-read-evidence.md)
- `publish-body` — [`snippets-publish-body.md`](skill://gitlab/reference/snippets-publish-body.md)
- `mutate-finish` — [`snippets-mutate-finish.md`](skill://gitlab/reference/snippets-mutate-finish.md)

| Snippet | Purpose | Group |
|---|---|---|
| `local-repo-preflight` | Bind project, default branch, and local git/ref state. | read-evidence |
| `issue-pickup` | Select and read issues; state/label checks stay body-free. | read-evidence |
| `mr-pickup` | Select and read one MR for decision-grade metadata. | read-evidence |
| `artifact-capture` | Capture MR comments, JSON, and diff into a run dir. | read-evidence |
| `safe-mr-json` | Guard-grade MR workflow metadata, no list-only data. | read-evidence |
| `sha-guard` | Compare current MR head against the reviewed SHA. | read-evidence |
| `ci-decision-snapshot` | One-shot advisory CI/merge-status read. | read-evidence |
| `ci-watch-sha-pinned` | Poll exact-SHA pipelines as advisory progress evidence. | read-evidence |
| `approval-confirmation` | Verify approval through the approvals endpoint. | read-evidence |
| `mr-handoff-evidence` | Read-only handoff claims vs verified bindings. | read-evidence |
| `draft-mr-create` | Open the early Draft MR with a validated description. | publish-body |
| `mr-description-update` | Refresh description/Reviewer Lift, no state change. | publish-body |
| `draft-mr-mark-ready` | Draft to ready at the gated head SHA. | publish-body |
| `mr-note-create` | Post one validated MR note (Review Reports, status). | publish-body |
| `issue-note-create` | Post one validated issue note. | publish-body |
| `label-reconcile` | Apply a checked label add/remove set to an issue. | publish-body |
| `sha-bound-approval` | Approve, pinned to the reviewed SHA. | mutate-finish |
| `sha-bound-merge` | Direct merge, pinned to the reviewed SHA. | mutate-finish |
| `sha-bound-auto-merge-queue` | Queue auto-merge, pinned to the reviewed SHA. | mutate-finish |
| `auto-merge-api-fallback` | Documented auto-merge queue fallback boundary. | mutate-finish |
| `finish-mr-authority-aware` | One authority-scoped finish action and readback. | mutate-finish |

## Troubleshooting

JSON shape wrong: inspect keys and adapt projection only.
