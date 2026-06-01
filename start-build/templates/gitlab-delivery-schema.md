# GitLab Delivery Schema

Canonical shared schema for compact GitLab delivery blocks. This file owns the
field names, field order, and enum vocabulary for `delivery.kind =
gitlab-delivery`. The block is an additive routing index around GitLab records;
it never replaces MR metadata, Review Packets, Review Reports, Gate Receipts, CI
checks, or authority verification.

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
| local_gate | Local gate command/status plus `not_run_reason` when not run. |
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
- `repo-file`
- `test-output`
- `run-artifact`
- `git-ref`
- `human-authority`
- `delivery-index`

## `not_run_reason` enum

`not_run_reason` is required when `pipeline.status`, `local_gate.status`, or any
action is `N/A`/`not-run`; otherwise use `N/A`.

- `N/A`
- `parent-owned-final-gate`
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

- Builder: `spawn-reviewer`, `human-decision`, `fix-blocker`
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
