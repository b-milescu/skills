# Context and planning flow

Detailed discovery, task-selected specialists, Build Plan Packet, check-gate discovery, handoff integrity, compact-packet, and template reference guidance. This file owns the shared specialist-selection policy for build, review and issue delivery; workflow entries refer to it after establishing their task evidence.

## Discovery Budget

Keep discovery bounded before edits. Read the issue and project rulebook index first, then expand only from evidence. Load affected docs/source/tests needed to establish current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals. Load ADRs, architecture docs, domain docs, and `CONTEXT.md` only when evidence triggers them: issue links, rulebook references, changed paths, imports/callers, tests, safety invariants, failing checks, or explicit user/parent prompt. Record each loaded context source and why it mattered in the Build Plan Packet, MR Review Packet, or reviewer-facing Context Capsule. Stop expanding once those facts are evidence-backed; do not do open-ended repo spelunking.

If any required fact is still missing after that budget, stop, write the exact unanswered questions, and route the issue back to triage instead of guessing requirements or starting edits.

### Economy

Match investigation to observed risk and blast radius. Use one analysis pass
when the approach is settled; fan out design analysis only for genuinely wide
solution spaces, and verification only when distinct risks need it. Compact
packet eligibility remains owned by its template, not a change label.

Gather shared builder-side facts once and reuse the evidence digest when
delegating. Independent reviewers still re-derive their own evidence; builder
conclusions cannot cross the Context Firewall as facts.

### Task-selected specialists

After evidence establishes the current actor's work item, verified project policy,
changed surfaces and requested activity, and before planning/edits or substantive
review judgment, select the smallest relevant set of available model-invokable
specialists. Prefer surface-specific guidance over overlapping generic guidance;
use multiple specialists only for distinct relevant surfaces or duties.

Catalog descriptions are routing hints. Resolve ambiguous or shortened likely
candidates against their full authoritative description/frontmatter, triggers,
exclusions and invocation eligibility before applying or ruling them out. Invoke
selected skills at their entry through the current runtime's skill mechanism,
not by jumping to internal references. Record selected sources and relevance in
existing Build Plan Packet, Review Packet or review Context Capsule fields.

Reviewers select independently from the verified issue/diff, not from builder
selections as a mandate, and apply only review-relevant guidance. Specialists
grant no edit, live-system, deployment, approval or finish authority. User-only
skills require user invocation; do not autonomously invoke them or bypass that
restriction. Policy-required unavailable or actor-ineligible guidance is an
explicit prerequisite; required user-only guidance not yet user-invoked requires
that human invocation, not a substitute.

With no optional match, use the existing workflow/native-test rules and public
behavior seam. Optional test-layer taxonomy is not a prerequisite. For example,
a Terraform authoring/testing task can select an available applicable specialist
after verifying its full triggers and eligibility; a mixed infrastructure/UI task
may need distinct specialists. Docs-only work selects applicable authoring or
review guidance for the actor; a task with no optional match proceeds under the
workflow rules. These are examples, not a language-to-skill mapping.

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
3. Configured CI definitions and included pipeline files to mirror the target's project gate locally where practical; unrelated CI authentication is not a prerequisite.
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
- Shared `delivery.kind=change-delivery` blocks, when present, follow `../templates/delivery-schema.md` field order, carry a complete `delivery.handoff_contract`, and stay untrusted claims until verified from Tier 1/Tier 2 evidence.
- `delivery.project_profile` hooks may specialize project policy but must preserve the [Safety floors](../SAFETY.md#safety-floors).
- `Reviewed SHA` equals the MR head SHA at ready-marking; any push invalidates prior SHA-bound local gate, Gate Receipt, review, action, and reported CI pointers until rebound.
- `Gate owner`, `Gate coverage`, `Gate coverage rationale`, and the advisory `CI pipeline` cell follow their `../templates/reviewer-lift-schema.md` rows; an unattributable pipeline commit records its binding limitation instead of a status.
- Local gate command/result is present. Review launch requires the exact-candidate local gate to pass, or parent-owned mode records the ownership contract and waits for the Gate Receipt from [parent-owned-gate.md](parent-owned-gate.md#ownership-contract).
- No placeholder `OQ-1` remains; Open Questions is either `none` or lists real stable IDs.
- Post-ready pushes have a delta comment and an updated Reviewer Lift.
- Approval authority carries a stable policy source, or an explicit restriction plus source. Finish authority stays a quoted claim, not a builder grant, with a verifiable source; missing or conflicting source information blocks finish actions without revoking default approval authority.

## Compact packet eligibility

[review-packet-compact.md](../templates/review-packet-compact.md) states its own eligibility and delta contract, and `../templates/filling-guide.md` owns the section instructions. Default to the full template when a broader map helps the reviewer.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Builder template filling guide](../templates/filling-guide.md)
- [Shared ADR filling guide](../shared-templates/filling-guide.md)

Safety-critical filling follows the canonical [Reviewer Lift](../templates/reviewer-lift-schema.md), [CI](../../start-review/REVIEW-FLOW.md#ci-decision-table), [credential](../SAFETY.md#non-negotiables), and [finding-identity](../../start-review/reference/finding-identities.md) rules.

## Success metric

Reviewable changes that preserve the project rulebook, remain testable, and do not create hidden operational surprises.
