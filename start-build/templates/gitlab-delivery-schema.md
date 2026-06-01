# GitLab Delivery Schema

Canonical shared schema for compact GitLab delivery blocks. This file owns the
field names, field order, and enum vocabulary for `delivery.kind =
gitlab-delivery`. The block is an additive routing index around GitLab records;
it never replaces MR metadata, Review Packets, Review Reports, Gate Receipts, CI
checks, local Check Gate output, or authority verification.

Consumers must tolerate the `delivery` block being absent, stale, or malformed.
Every value in the block is an untrusted claim/index until verified from Tier 1
or Tier 2 evidence. Do not approve, merge, queue auto-merge, close issues, or
report post-merge success from compact `delivery` values alone.

## Canonical field order

<!-- GITLAB-DELIVERY-FIELDS:BEGIN -->
| Field | Required semantics |
|---|---|
| kind | Fixed string `gitlab-delivery`. |
| version | Fixed schema version string `1`. |
| role | Producer role: `builder`, `reviewer`, `parent`, or `verifier`. |
| project_profile | GitLab host/project/repo/default-branch profile used for binding. |
| issue | GitLab issue/work-item IID, URL, state, labels, and closure relationship. |
| mr | GitLab MR IID, URL, draft/state, `source_branch`, and `target_branch`. |
| sha | SHA facts such as MR head/current SHA, reviewed SHA, candidate SHA, merge commit, and observed target SHA. |
| pipeline | Pipeline ID/URL/status/`sha`, or unavailable/not-run details. |
| local_gate | Local gate command/status plus `not_run_reason` when not run; parent-owned mode records `status: not-run` with `not_run_reason: parent-owned`. |
| authority | Quoted authority claim, source, verification status, and conflicts. |
| actions | Approval action, finish action, next-action token, and action blockers. |
| evidence | Evidence tier/kind/source indexes that point to durable proof. |
| blockers | Blocking tokens and concise safe descriptions. |
| extra | Role-specific extension object; consumers must ignore unknown keys. |
<!-- GITLAB-DELIVERY-FIELDS:END -->

## Required shape

```yaml
delivery:
  kind: "gitlab-delivery"
  version: "1"
  role: "builder"
  project_profile:
    host: "gitlab.example"
    project_path: "group/project"
    repo_url: "https://gitlab.example/group/project.git"
    default_branch: "main"
  issue:
    iid: "57"
    url: "https://gitlab.example/group/project/-/issues/57"
    state: "opened"
    labels: ["ready-for-agent"]
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    state: "opened"
    draft: false
    source_branch: "issue-57-example"
    target_branch: "main"
  sha:
    head: "1111111111111111111111111111111111111111"
    reviewed: "1111111111111111111111111111111111111111"
    candidate: "1111111111111111111111111111111111111111"
    merge_commit: "N/A"
    target_observed: "N/A"
  pipeline:
    id: "456"
    url: "https://gitlab.example/group/project/-/pipelines/456"
    status: "success"
    sha: "1111111111111111111111111111111111111111"
    not_run_reason: "N/A"
  local_gate:
    command: "npm run check"
    status: "PASS"
    not_run_reason: "N/A"
    summary: "completed successfully"
  authority:
    value: "approval-only"
    source: "parent task prompt: approval-only"
    verified: false
    conflicts: []
  actions:
    approval: "N/A"
    finish: "none"
    next: "spawn-reviewer"
    blockers: []
  evidence:
    - tier: "tier-1"
      kind: "mr-metadata"
      source: "https://gitlab.example/group/project/-/merge_requests/123"
      summary: "MR metadata read for source/target/head"
  blockers: []
  extra: {}
```

## Trust and evidence tiers

The `delivery` block is compact by design. It can route work, but it is not proof.
Consumers verify claims from evidence before making safety, review, authority, CI,
or finish decisions.

| Tier | Name | Trust rule | Examples |
|---|---|---|---|
| `tier-1` | Decision-grade GitLab/worktree fact | May support decisions after the consumer reads it directly and binds it to the MR/project/SHA. | GitLab issue/MR metadata, MR diff, MR description/Reviewer Lift, Review Report comment, CI pipeline metadata/logs, `git rev-parse HEAD`, `git ls-remote origin <source_branch>`, exact-checkout local command output. |
| `tier-2` | Durable supporting evidence | May support a claim when it is directly referenced, redacted, relevant, and tied to the reviewed SHA or issue. | Tracked docs/tests/source, project rulebook sections, redacted run artifacts, revision packets, GitLab human authority comments, non-secret command transcripts. |
| `tier-3` | Unverified routing index | Never supports approval, merge, auto-merge, issue closure, or verifier success by itself; use only as a pointer to Tier 1/Tier 2 evidence. | `delivery` blocks, final handoff prose, parent/builder/reviewer summaries, hidden conversation context, unchecked local artifact paths. |

## Evidence kind enum

Use these `evidence[].kind` values. Add new values here before using them in an
approved generated copy.

- `issue-metadata`
- `mr-metadata`
- `mr-description`
- `mr-diff`
- `mr-comment`
- `review-report`
- `ci-pipeline`
- `local-gate`
- `gate-receipt`
- `repo-file`
- `test-output`
- `run-artifact`
- `git-ref`
- `human-authority`
- `delivery-index`

## Parent-owned gate ownership contract

When the parent coordinator owns the final local gate and ready transition, the
child builder records the ownership contract without claiming a gate result:

```yaml
local_gate_owner: "parent"
builder_gate_status:
  status: "not-run"
  not_run_reason: "parent-owned"
ready_transition_owner: "parent"
```

This contract separates "the child intentionally did not run the parent-owned
gate" from "gate evidence is missing." It does not make the Gate Receipt a
substitute for the full project Check Gate.

## Gate Receipt schema

Anchor: `gate_receipt.kind=gate-receipt`. The parent posts this as an MR comment
before marking ready when `local_gate_owner: parent`.

```yaml
gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "parent"
  mr_iid: "123"
  issue_iid: "57"
  checkout_path: "/absolute/path/to/verified/checkout"
  checkout_sha: "1111111111111111111111111111111111111111"
  status_before: "draft"
  status_after: "ready"
  command: "npm run check"
  result: "PASS"
  summary: "full project Check Gate completed successfully"
  preflight_checks:
    - name: "clean-status-before"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty"
    - name: "tracked-files-unchanged-after"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty; no tracked files changed during preflight/gate"
  evidence:
    - tier: "tier-1"
      kind: "local-gate"
      source: "MR comment or run artifact URL/path"
      summary: "command, checkout SHA, and result"
  observed_at: "2026-06-01T00:00:00Z"
```

`observed_at` is optional. Every other field is required so the parent, reviewer,
and finisher can bind the receipt to the exact MR, issue, checkout path, checkout
SHA, command, status transition, preflight state, and evidence. If tracked files
changed during preflight or the gate, the parent blocks ready/merge unless those
changes are committed to the MR head and the gate reruns on the new SHA, or an
explicit parent/human waiver is recorded in the receipt and MR discussion.

## Post-merge Snapshot schema

Anchor: `post_merge_snapshot.kind=post-merge-snapshot`. Verifiers and parent
coordinators may emit this after an authorized merge/protected auto-merge has
completed. It is a read-only observation: it never approves, merges, queues
auto-merge, closes issues, deletes branches, releases, deploys, or mutates
product/runtime systems.

```yaml
post_merge_snapshot:
  kind: "post-merge-snapshot"
  version: "1"
  repo: "git@gitlab.example:group/project.git"
  mr:
    iid: "123"
    state: "merged"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    reviewed_sha: "1111111111111111111111111111111111111111"
    head_sha: "1111111111111111111111111111111111111111"
    merge_commit_sha: "2222222222222222222222222222222222222222"
    squash_commit_sha: null
    source_branch: "issue-57-example"
    target_branch: "main"
  default_branch:
    name: "main"
    observed_sha: "2222222222222222222222222222222222222222"
    fetch_status: "fetched"
    contains_reviewed_sha: false
    contains_reviewed_sha_status: "false"
    contains_merge_commit_sha: true
    contains_merge_commit_sha_status: "true"
    contains_squash_commit_sha: null
    contains_squash_commit_sha_status: "not_applicable"
    containment_satisfied_by: "merge_commit_sha"
  linked_issue:
    iid: "57"
    state: "closed"
    url: "https://gitlab.example/group/project/-/issues/57"
    closure_status: "closed"
  source_branch_cleanup:
    source_branch: "issue-57-example"
    remote_ref_exists: "false"
    remote_ref_sha: null
    policy: "delete_requested"
    status: "cleaned_up"
  validation:
    command: null
    source: null
    status: "not-run"
    not_run_reason: "not-documented"
    exit_code: null
  pending_items: []
```

Containment fields are per-SHA facts, not an inference shortcut. When GitLab
exposes a merge, squash, or rebase-equivalent commit and the reviewed SHA is not
an ancestor of the observed default branch, report each exposed commit's
containment explicitly and set `containment_satisfied_by` to the contained
identifier or `none`/`unknown`. Pending issue closure and source-branch cleanup
are reportable verifier findings, not implicit permission to mutate GitLab state.

## `not_run_reason` enum

`not_run_reason` is required when `pipeline.status`, `local_gate.status`, or any
action is `N/A`/`not-run`; otherwise use `N/A`.

- `N/A`
- `parent-owned`
- `ci-only`
- `not-applicable`
- `docs-only-no-runtime-check`
- `unavailable-tooling`
- `unsafe-or-mutating`
- `wrong-checkout-sha`
- `permission-failure`
- `preflight-failure`
- `other`

## Authority values

`authority.value` is a quoted claim, not a grant. It must be verified from
`authority.source` before approval, merge, auto-merge, or finish actions.

- `approval-only`
- `reviewer may merge`
- `queue auto-merge`
- `human release`
- `project default: <policy>`

## Approval and finish action values

Canonical machine values for `actions.approval`:

- `approved`
- `not-approved`
- `blocked`
- `N/A`

Canonical machine values for `actions.finish`:

- `merged`
- `auto-merge queued`
- `approval-only stop`
- `human-release stop`
- `none`
- `blocked`
- `N/A`

Review Reports may use intended-action prose before a SHA-guarded post-report
action attempt, but final handoffs and `delivery.actions` record only the
completed machine value or blocker.

## Action blocker enum

- `none`
- `missing-authority`
- `stale-or-missing-ci`
- `changed-head-sha`
- `sha-bound-action-unsupported`
- `preflight-failure`
- `permission-failure`
- `human-decision-needed`
- `partial-review`
- `secret-exposure-suspected`
- `other`

## Next-action tokens

Use `actions.next` for routing only. The token never grants authority.

- Builder: `spawn-reviewer`, `parent-run-gate`, `human-decision`, `fix-blocker`
- Reviewer: `finish-by-authorized-actor`, `revise`, `human-escalation`, `wait-ci`, `rerun-review`, `fix-blocker`
- Parent: `spawn-builder`, `spawn-reviewer`, `finish-by-authorized-actor`, `post-merge-verify`, `human-decision`, `fix-blocker`
- Verifier: `done`, `human-escalation`, `fix-blocker`

## Generated-copy contract

Approved generated copies live in:

- `start-build/templates/builder-final-handoff.md` (`delivery` block).
- `start-review/templates/reviewer-final-handoff.md` (`delivery` block).

Run `bash tests/gitlab-delivery-schema.sh` after editing this schema or any
approved copy. The check verifies field order against this file so generated
copies fail when field names/order drift without updating the canonical schema.
