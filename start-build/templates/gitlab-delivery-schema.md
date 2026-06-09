# GitLab Delivery Schema

Canonical shared schema for compact GitLab delivery blocks. This file owns the
field names, field order, and enum vocabulary for `delivery.kind =
gitlab-delivery`. The block is an additive routing index around GitLab records;
it never replaces MR metadata, Review Packets, Review Reports, Gate Receipts
(canonical in `../reference/parent-owned-gate.md`), CI checks, local Check Gate
output, or canonical Authority Verification (`../../gitlab/reference/authority-verification.md`).

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
| acceptance_surfaces | Declared acceptance surfaces and per-surface evidence status. Each entry names one taxonomy surface and its evidence (`test`, `smoke`, `docs-read`, `ci`, or `N/A — <reason>`). Use empty list when no named surface is touched. |
| authority | Quoted approval and merge/finish authority claims, sources, Authority Verification status, and conflicts/restrictions. |
| actions | Approval action, finish action, next-action token, and action blockers. |
| handoff_contract | Shared routing block naming phase, next actor/action, blocker state, parent-decision need, change flag, and evidence-ready pointers. |
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
    profile_id: "default"
    profile_path: "docs/agents/dev-workflows.md#project-profile-hooks"
    gate_policy_ref: "docs/agents/check-gate.md#full-local-gate"
    label_profile_ref: "docs/agents/triage-labels.md#live-label-inventory"
    language_families:
      - "typescript"
      - "shell"
      - "markdown"
    auxiliary_index_policy:
      ref: "docs/agents/dev-workflows.md#auxiliary-project-index-policy"
      owner: "parent"
      child_worktree_mode: "read-only-unless-assigned"
      copy_between_worktrees: "forbidden"
    branch_naming:
      ref: "docs/agents/dev-workflows.md#branch-naming"
      pattern: "issue-<iid>-<slug>"
    ci_jobs:
      ref: "docs/agents/check-gate.md#ci-parity"
      required:
        - "check"
    domain_docs:
      ref: "docs/agents/domain.md"
      context: "CONTEXT.md"
      adr: "docs/adr/"
    release_deploy_policy:
      ref: "docs/agents/dev-workflows.md#release-deploy-policy"
      policy: "project docs define release/deploy authority"
    manual_validation_rules:
      ref: "docs/agents/check-gate.md#manual-validation-rules"
      required: []
  issue:
    iid: "57"
    url: "https://gitlab.example/group/project/-/issues/57"
    state: "opened"
    labels: ["target-afk-ready-label"]
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
  acceptance_surfaces: []
  authority:
    approval:
      value: "default-after-pass"
      source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
      verified: false
      restricted: false
    merge:
      value: "approval-only"
      source: "parent task prompt: approval-only"
      verified: false
      conflicts: []
  actions:
    approval: "N/A"
    finish: "none"
    next: "spawn-reviewer"
    blockers: []
  handoff_contract:
    phase: "review"
    expected_next_actor: "reviewer"
    expected_next_action: "spawn-reviewer"
    blocked: false
    blocker_token: "none"
    required_parent_decision: "none"
    safe_to_continue_without_parent: true
    changed_since_last_handoff: false
    evidence_ready_for_next_actor:
      - "review-packet-current"
      - "reviewer-lift-current"
  evidence:
    - tier: "tier-1"
      kind: "mr-metadata"
      source: "https://gitlab.example/group/project/-/merge_requests/123"
      summary: "MR metadata read for source/target/head"
  blockers: []
  extra: {}
```

## Project profile extension fields

`project_profile` binds the GitLab delivery block to the concrete project and is
the only place this schema exposes bounded project-specific extension hooks. The
global delivery field names remain GitLab-specific: `issue`, `mr`, `pipeline`,
`source_branch`, `target_branch`, and `sha`. Do not add provider-neutral aliases
for those fields.

| Field | Required semantics |
|---|---|
| `host` | GitLab host used for project binding. |
| `project_path` | GitLab namespace/project path used for repo/MR/issue binding. |
| `repo_url` | Git remote URL used for local preflight and guarded fallback/helper operations. |
| `default_branch` | Target branch used for source/target binding and exact-SHA comparisons. |
| `profile_id` | Stable project-profile identifier such as `default`, `regulated`, or a target-repo slug. |
| `profile_path` | Repo-local doc path that owns the profile declaration. |
| `gate_policy_ref` | Repo-local gate policy reference; usually `docs/agents/check-gate.md`. |
| `label_profile_ref` | Repo-local label vocabulary reference; usually `docs/agents/triage-labels.md`. |
| `language_families` | Project language/tooling families that inform local gate discovery and reviewer focus. |
| `auxiliary_index_policy` | Ownership/read-only rules for auxiliary project indexes such as graph or search artifacts. |
| `branch_naming` | Repo-local branch naming convention for source branches; this does not rename `source_branch` or `target_branch`. |
| `ci_jobs` | CI job names/requirements that must be SHA-bound before they count as green evidence. |
| `domain_docs` | Domain, context, and ADR locations that project-aware agents should read when relevant. |
| `release_deploy_policy` | Repo-local release/deploy authority and validation references. |
| `manual_validation_rules` | Manual validation requirements and allowed evidence when automation is unavailable. |

Project-profile hooks may specialize project policy, but they must not weaken
reviewed-SHA binding, exact-SHA CI, explicit authority source, independent
review, the child-builder boundary, the verifier read-only boundary, or
MCP-first transport correctness plus help-first `glab` fallback correctness.
Compact delivery values, including
`project_profile`, remain routing indexes until verified from Tier 1/Tier 2
evidence.

Auxiliary project-index policy defaults to parent/coordinator ownership:
parent/coordinator checkouts update generated project indexes unless
`auxiliary_index_policy` explicitly assigns that work elsewhere. Child
worktrees treat index reports as read-only unless explicitly assigned and must
not copy index artifacts between worktrees.

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

## Parent-owned Check Gate / Gate Receipt seam

The parent-owned Check Gate ownership contract, Gate Receipt schema, parent
verification checklist, ready-transition conditions, and evidence-ready tokens
are canonical in [`../reference/parent-owned-gate.md`](../reference/parent-owned-gate.md)
(`skill://start-build/reference/parent-owned-gate.md` when invoked from another
repo).

This delivery schema keeps only the routing vocabulary for that seam:

- `local_gate.status: "not-run"` with `not_run_reason: "parent-owned"`;
- evidence kind `gate-receipt`;
- next-action token `parent-run-gate`;
- `gate_receipt.kind=gate-receipt` as the receipt anchor.

Delivery blocks remain untrusted indexes. The parent and reviewer must read the
canonical seam and decision-grade GitLab/worktree evidence before using a Gate
Receipt for ready, review, approval, or finish routing.

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

## Acceptance surfaces taxonomy

`acceptance_surfaces` is a list of objects, each naming one touched surface and
its evidence status. Use an empty list (`[]`) when no named surface is touched.
Builders declare surfaces; parents verify all declared surfaces have evidence
before ready; reviewers verify each declared surface against evidence before pass.

Compact string form: `"surface:evidence"` (e.g. `"docs:docs-read"`).
Object form: `{surface: "docs", evidence: "docs-read"}`.

Allowed `surface` values:

- `docs` — documentation files changed or read as evidence.
- `prompt` — agent prompt / SKILL.md / agent definition file changed.
- `agent_inventory` — agent inventory manifest or registry changed.
- `install_surface` — install script, symlink, or deploy artifact changed.
- `transport` — GitLab transport / MCP / glab fallback logic changed.
- `authority` — authority verification, approval, or merge authority logic changed.
- `ci_finish` — CI watch, finish guard, or CI-verdict logic changed.
- `mutation_guard` — GitLab mutation guard or safe-text handling changed.

Allowed `evidence` values per surface:

- `test` — targeted automated test covers the surface.
- `smoke` — manual or scripted smoke check performed.
- `docs-read` — documentation-level change verified by reading.
- `ci` — CI pipeline covers the surface at the reviewed SHA.
- `N/A — <reason>` — surface not exercised; reason documented.

## Authority values

Authority claim shape, source precedence, conflict/restricted/missing-source
results, action routing, and no-self context are canonical in
[`../../gitlab/reference/authority-verification.md`](../../gitlab/reference/authority-verification.md).
Delivery `authority` values are routing claims until that seam verifies them from
Tier 1/Tier 2 evidence.

`authority.approval.value` is a quoted approval-policy claim, not a grant of any
finish action. It must be verified from `authority.approval.source` before
approval. Default approval after pass still requires the reviewed SHA, CI/local
gate/OQ, review coverage, and SHA-bound approval guards.

- `default-after-pass`
- `restricted: <reason/source>`

`authority.merge.value` is a quoted finish-authority claim, not a grant. It must
be verified from `authority.merge.source` before merge, auto-merge, release,
close, cleanup, or other finish actions. Missing merge authority blocks finish
only; it does not revoke default approval authority by itself.

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

Use `actions.next` and `handoff_contract.expected_next_action` for routing only.
The token never grants authority.

- Builder: `spawn-reviewer`, `parent-run-gate`, `human-decision`, `fix-blocker`
- Reviewer: `finish-by-authorized-actor`, `revise`, `human-escalation`, `wait-ci`, `rerun-review`, `fix-blocker`
- Parent: `spawn-builder`, `spawn-reviewer`, `finish-by-authorized-actor`, `post-merge-verify`, `human-decision`, `fix-blocker`
- Verifier: `done`, `human-escalation`, `fix-blocker`

## Handoff contract

`handoff_contract` is the shared cross-role routing block nested under
`delivery`. It complements `actions.next`; when both appear,
`handoff_contract.expected_next_action` must match `actions.next`.

Required fields:

- `phase`
- `expected_next_actor`
- `expected_next_action`
- `blocked`
- `blocker_token`
- `required_parent_decision` — use `none` or a concise decision still needed from the parent/human owner.
- `safe_to_continue_without_parent`
- `changed_since_last_handoff`
- `evidence_ready_for_next_actor`

Optional fields:

- `blocking_question` — include only when a specific actionable question blocks
  progress.

`phase` values:

- `builder-ready`
- `parent-gate`
- `review`
- `revision`
- `finish`
- `post-merge-verify`
- `done`
- `blocked`

Common `expected_next_actor` values: `builder`, `reviewer`, `parent`,
`verifier`, `human`.

`blocked: true` means forward progress is stopped on a real blocker token;
`blocker_token` uses the Action blocker enum or `none`.

`safe_to_continue_without_parent` is `false` when more parent/human direction
is still required before the expected next actor can safely continue.

`changed_since_last_handoff` is `true` when commits, gate evidence, or review
conclusions changed since the prior ready/revision/finish handoff.

`evidence_ready_for_next_actor` is a non-empty list of concise pointers/tokens
describing what the next actor can verify immediately. Parent-owned gate mode
uses the evidence-ready tokens from `../reference/parent-owned-gate.md`.

## Generated-copy contract

Approved generated copies live in:

- `start-build/templates/builder-final-handoff.md` (`delivery` block).
- `start-review/templates/reviewer-final-handoff.md` (`delivery` block).

Run `bash tests/gitlab-delivery-schema.sh` after editing this schema or any
approved copy. The check verifies field order against this file so generated
copies fail when field names/order drift without updating the canonical schema.
