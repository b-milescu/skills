# Change Delivery Schema

Canonical compact routing index for all supported forges. This file owns the
field order and vocabulary for `delivery.kind=change-delivery` version 1.
Artifacts count as evidence only through their verified source and readback,
never by artifact name. Consumers tolerate an absent, stale, or malformed block
and rebind every claim before acting.

Generic IDs and artifact locators are opaque strings. Only the bound provider
interprets or validates its native ID and URL shapes.

Gate Receipt fields, parent-owned ready behavior, and
[stage-correct verification](../reference/parent-owned-gate.md#stage-correct-handoff-verification)
are canonical in [parent-owned-gate.md](../reference/parent-owned-gate.md);
`gate_receipt.kind=gate-receipt` is a durable workflow artifact, not a compact
delivery record. Final handoffs follow
[builder-final-handoff.md](builder-final-handoff.md) and the
[reviewer contract](../../start-review/templates/reviewer-final-handoff.md).

## Canonical field order

<!-- CHANGE-DELIVERY-FIELDS:BEGIN -->
| Field | Required semantics |
|---|---|
| kind | Fixed string `change-delivery`. |
| version | Fixed string `1`. |
| role | `builder`, `reviewer`, `parent`, or `verifier`. |
| provider | Bound provider name, profile, and provider-specific reference. |
| repository | Canonical host/repository/default-branch binding plus policy hooks. |
| issue | Opaque identifier/locator, state, labels, and closure relationship. |
| change_request | Opaque identifier/locator, state, draft flag, source, and target. |
| commit | Current, reviewed, candidate, result, and observed-target commit IDs. |
| ci | Opaque run locator/status/commit binding or not-run rationale. |
| local_gate | Command, status, not-run reason, and summary. |
| tdd | RED/GREEN commands and outcomes, or explicit N/A rationale. |
| authority | Approval and finish claims, sources, verification, and conflicts. |
| handoff_contract | Required in supported compact delivery indexes: phase, next actor/action, blocker state, decision need, and evidence-ready pointers. Builder-final and reviewer-final handoffs use only the two-line locator contract; parents derive routing from native evidence instead. |
| evidence | Tiered durable evidence indexes. |
| blockers | Safe blocking tokens/descriptions. |
<!-- CHANGE-DELIVERY-FIELDS:END -->

## Required shape

```yaml
delivery:
  kind: "change-delivery"
  version: "1"
  role: "builder"
  provider:
    name: "<confirmed opaque integration name>"
    profile: "<confirmed target profile id>"
    reference: "<target-owned integration doc or section>"
  repository:
    host: "<verified system scope, when remote>"
    id: "<verified repository or local filesystem scope>"
    locator: "<opaque verified repository locator>"
    default_branch: "main"
    profile_path: "<confirmed target profile pointer>"
    gate_policy_ref: "<confirmed target gate policy>"
    label_profile_ref: "<confirmed target label vocabulary>"
    acceptance_surfaces_ref: "<confirmed target surface vocabulary>"
    language_families: ["typescript", "shell", "markdown"]
    auxiliary_index_policy:
      owner: "parent"
      child_worktree_mode: "read-only-unless-assigned"
      copy_between_worktrees: "forbidden"
    branch_naming:
      pattern: "issue-<id>-<slug>"
    ci_jobs:
      observed: ["check"]
    domain_docs:
      context: "CONTEXT.md"
      adr: "docs/adr/"
    release_deploy_policy:
      policy: "project docs define release/deploy authority"
    manual_validation_rules:
      required: []
  issue:
    id: "57"
    locator: "provider://issue/57"
    state: "open"
    labels: ["ready"]
  change_request:
    id: "123"
    locator: "provider://change/123"
    state: "open"
    draft: true
    source: "issue-57-example"
    target: "main"
  commit:
    current: "1111111111111111111111111111111111111111"
    reviewed: "1111111111111111111111111111111111111111"
    candidate: "1111111111111111111111111111111111111111"
    result: "N/A"
    target_observed: "N/A"
  ci:
    id: "456"
    locator: "provider://ci/456"
    status: "success"
    commit: "1111111111111111111111111111111111111111"
    not_run_reason: "N/A"
  local_gate:
    command: "bun run check"
    status: "not-run"
    not_run_reason: "parent-owned"
    summary: "parent owns the final local gate"
  tdd:
    red: "targeted test failed for the expected missing behavior"
    green: "targeted test passed"
  authority:
    approval:
      value: "default-after-pass"
      source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
      verified: false
      restricted: false
    finish:
      value: "none — requires explicit human/parent instruction"
      source: "workflow default"
      verified: false
      conflicts: []
  handoff_contract:
    phase: "parent-gate"
    expected_next_actor: "parent"
    expected_next_action: "parent-run-gate"
    blocked: false
    blocker_token: "none"
    required_parent_decision: "none"
    safe_to_continue_without_parent: true
    changed_since_last_handoff: false
    evidence_ready_for_next_actor: ["change-request-description-current", "candidate-commit-pushed"]
  evidence:
    - tier: "tier-1"
      kind: "change-request-metadata"
      source: "provider://change/123"
      summary: "provider-native source/target/current commit snapshot"
  blockers: []
```

Authority Verification uses `../../forge/reference/common-guard.md` and native mechanics from the invoked target's selected confirmed reference.

## Provider and repository binding

`forge preflight` binds intended scopes together through the invoked target's confirmed profile/reference, refreshing only systems required by the requested operation. Independently scoped work items/code/CI and local filesystem work items require explicit verified scope, not invented remote identity. Configuration grants no authority. Profile hooks preserve the [Safety floors](../SAFETY.md#safety-floors).

## Trust and evidence tiers

| Tier | Trust |
|---|---|
| Tier 1 | Provider-native decision-grade evidence. |
| Tier 2 | Repository policy/source/tests and verified run evidence. |
| Tier 3 | Unverified routing index and claims used only as pointers. |

`routing index` is the canonical term for unverified handoff data; rebind it to Tier 1 or Tier 2 evidence before action.

## Authority values

- Gate status: `PASS`, `FAIL`, `N/A`, or `not-run`; not-run reason includes
  `parent-owned`, `unavailable-tooling`, `not-required`, and `other`.
- Finish authority: `none — requires explicit human/parent instruction`,
  `approval-only`, `reviewer may merge`, `queue auto-merge`, `human release`, or
  an affirmatively granted project default. A granting value authorizes only the
  action it names: `queue auto-merge` queues, while `reviewer may merge` or a
  project default naming direct merge merges directly; neither implies the other.
- Handoff actions include `parent-run-gate`, `spawn-reviewer`, `rerun-review`,
  `approve`, `finish`, `verify-post-merge`, `human-decision`, and `fix-blocker`.
- Queued finish is non-terminal; only `post_merge_snapshot` may establish the
  merged result, linked-item state, advisory result-commit CI, and branch cleanup.

## Generated-copy contract

This schema is not copied into builder-final or reviewer-final handoffs.
Those templates emit the two-line locator/note-id contract. Native verification,
gate/finding helpers and resource-link checks cover the current consumers.
