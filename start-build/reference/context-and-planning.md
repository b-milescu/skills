# Context and planning flow

Detailed discovery, Build Plan Packet, check-gate discovery, handoff integrity, compact-packet, and template reference guidance for `start-build`. This file is the canonical owner of these sections; [SKILL.md](../SKILL.md) routes here from its compact invocation-mode procedure.

## Discovery Budget

Keep discovery bounded before edits. Read the issue and project rulebook index first, then expand only from evidence. Load affected docs/source/tests needed to establish current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals. Load ADRs, architecture docs, domain docs, and `CONTEXT.md` only when evidence triggers them: issue links, rulebook references, changed paths, imports/callers, tests, safety invariants, failing checks, or explicit user/parent prompt. Record each loaded context source and why it mattered in the Build Plan Packet, MR Review Packet, or reviewer-facing Context Capsule. Stop expanding once those facts are evidence-backed; do not do open-ended repo spelunking.

If any required fact is still missing after that budget, stop, write the exact unanswered questions, and route the issue back to triage instead of guessing requirements or starting edits.

## Build Plan Packet

Before the first edit, write a concise Build Plan Packet from the discovery result. Capture the issue, intended behavior, affected surfaces, test plan, risk, and non-goals. Also record loaded context sources with one-line reasons for why each source was relevant; omit boilerplate for sources that were not loaded. Keep it short enough that reviewers can compare it against the issue and diff without reading a long workflow body. Use [`../templates/build-plan-packet.md`](../templates/build-plan-packet.md) as the shape.

This packet is pre-edit planning only; builder and reviewer authority boundaries stay in [SKILL.md §Invocation modes](../SKILL.md#invocation-modes) and the active mode-specific flow ([child-builder.md](child-builder.md), [standalone-gate.md](standalone-gate.md), [parent-orchestrator.md](parent-orchestrator.md)).

## Check gate discovery

Discover the full local gate before claiming it is green.
Before selecting parent-owned gate mode or promising a parent Gate Receipt,
identify the required exact-candidate gate policy, exact command, and documented
bootstrap route (including runtime and dependencies). Discover them in this order:

1. Project rulebook / contributor docs (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README).
2. Build scripts (`Makefile`, `package.json`, task runner config, language-specific project files).
3. CI configuration (`.gitlab-ci.yml`, included pipeline files) to mirror the project gate locally where practical.
4. If still ambiguous, ask the user or state the limitation in the MR before requesting review.

For parent-mode selection, record the applicable case in the Build Plan Packet:

| Discovered case | Selection and prerequisite |
|---|---|
| Existing gate and bootstrap route | Parent ownership is supported; record policy, command, and bootstrap steps. |
| Existing gate, unbootstrapped checkout | Missing dependencies or the required runtime are bootstrap prerequisites, not missing gate policy. Record the documented setup route and who will execute it before the final gate. If setup is unavailable or unauthorized, name that precise prerequisite. |
| No gate policy or ambiguous command/bootstrap route | Parent receipt feasibility is unresolved. Name the missing policy decision, command, or setup instructions and route that question to the parent/human before promising a receipt. |
| Issue deliverable adds the gate | Parent ownership can be planned when the issue defines the gate policy, intended command, bootstrap route, and acceptance criteria. Implement those first, then run the gate on the final candidate; unresolved definitions require a policy decision, not a preimplementation pass. |

This is a feasibility check, not a demand for successful full-gate execution
before implementation. Unsupported parent-mode selection blocks only the
affected item: report its exact prerequisite or policy decision, preserve the
explicit `Gate owner` assignment, and continue unrelated supported work. Do not
silently fall back to builder ownership or substitute an N/A parent receipt.
Builder-owned evidence policy is outside this parent-mode selection rule.

## Handoff integrity checklist

Before marking ready or requesting review, validate the MR handoff:

- Reviewer Lift exists and its rows match `../templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema.
- Shared `delivery.kind=change-delivery` blocks, when present, satisfy each of the following:
  - follow `../templates/delivery-schema.md` field order;
  - include `delivery.handoff_contract` with `phase`, `expected_next_actor`, `expected_next_action`, `blocked`, `blocker_token`, `required_parent_decision`, `safe_to_continue_without_parent`, `changed_since_last_handoff`, and non-empty `evidence_ready_for_next_actor`;
  - are documented as untrusted claims/indexes until verified from Tier 1/Tier 2 evidence.

  `blocking_question` appears only when a specific actionable question is what blocks progress.
- `delivery.project_profile` hooks may specialize project policy but must preserve the [Hard floors (never scaled away)](../../docs/effort-scaling.md#hard-floors-never-scaled-away).
- `Reviewed SHA` equals the MR head SHA at ready-marking; any push invalidates prior SHA-bound local gate, Gate Receipt, review, action, and reported CI pointers until rebound.
- `Gate owner` is `builder` or `parent`; `Gate coverage` is `exact-candidate-local`. `Gate coverage rationale` cites the project gate policy, exact local command, candidate commit, and result.
- CI pipeline evidence is explicitly advisory and includes locator/ID, status, and commit when available. Attribute a status only when the pipeline commit matches `Reviewed SHA` or a provider-proven integration candidate; otherwise record the binding limitation.
- Local gate command/result is present. Review launch requires the exact-candidate local gate to pass, or parent-owned mode records the ownership contract and waits for the Gate Receipt from [parent-owned-gate.md](parent-owned-gate.md#ownership-contract).
- No placeholder `OQ-1` remains; Open Questions is either `none` or lists real stable IDs.
- Post-ready pushes have a delta comment and an updated Reviewer Lift.
- Approval authority is present as `default-after-pass` with a stable policy source, or an explicit approval restriction/source is recorded.
- Finish authority is explicit and treated as a quoted claim, not a builder grant.
- Finish authority source is present and verifiable; missing or conflicting source information blocks finish actions until a parent/human/rulebook source resolves it, but does not revoke default approval authority by itself.

## Compact packet eligibility

Use `../templates/review-packet-compact.md` when the diff is simple enough that a short MR description suffices: docs-only, tests-only with no runtime impact, typo/lint, or dependency bump with no API impact. The compact packet carries the same approved generated-copy Reviewer Lift rows from `../templates/reviewer-lift-schema.md` as the full packet, using explicit `N/A`/`none` values. Default to the full template when a broader map helps the reviewer.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Builder template filling guide](../templates/filling-guide.md)
- [Shared ADR filling guide](../shared-templates/filling-guide.md)

Safety-critical filling follows the canonical [Reviewer Lift](../templates/reviewer-lift-schema.md), [CI](../../start-review/REVIEW-FLOW.md#ci-decision-table), [credential](../SAFETY.md#non-negotiables), and [finding-identity](../../start-review/reference/finding-identities.md) rules.

## Success metric

Reviewable changes that preserve the project rulebook, remain testable, and do not create hidden operational surprises.
