# Context and planning flow

Detailed discovery, Build Plan Packet, check-gate discovery, handoff integrity, compact-packet, and template reference guidance for `start-build`. Stable compatibility anchors remain in [BUILD-FLOW.md](../BUILD-FLOW.md).

## Discovery Budget

Keep discovery bounded before edits. Read the issue and project rulebook index first, then expand only from evidence. Load affected docs/source/tests needed to establish current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals. Load ADRs, architecture docs, domain docs, and `CONTEXT.md` only when evidence triggers them: issue links, rulebook references, changed paths, imports/callers, tests, safety invariants, failing checks, or explicit user/parent prompt. Record each loaded context source and why it mattered in the Build Plan Packet, MR Review Packet, or reviewer-facing Context Capsule. Stop expanding once those facts are evidence-backed; do not do open-ended repo spelunking.

If any required fact is still missing after that budget, stop, write the exact unanswered questions, and route the issue back to triage instead of guessing requirements or starting edits.

## Build Plan Packet

Before the first edit, write a concise Build Plan Packet from the discovery result. Capture the issue, intended behavior, affected surfaces, test plan, risk, and non-goals. Also record loaded context sources with one-line reasons for why each source was relevant; omit boilerplate for sources that were not loaded. Keep it short enough that reviewers can compare it against the issue and diff without reading a long workflow body. Use [`../templates/build-plan-packet.md`](../templates/build-plan-packet.md) as the shape.

This packet is pre-edit planning only; builder and reviewer authority boundaries stay in [BUILD-FLOW.md §Builder invocation modes](../BUILD-FLOW.md#builder-invocation-modes) and the active mode-specific flow.

## Check gate discovery

Before you claim the full local gate is green, discover it in this order:

1. Project rulebook / contributor docs (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README).
2. Build scripts (`Makefile`, `package.json`, task runner config, language-specific project files).
3. CI configuration (`.gitlab-ci.yml`, included pipeline files) to mirror the project gate locally where practical.
4. If still ambiguous, ask the user or state the limitation in the MR before requesting review.

## Handoff integrity checklist

Before marking ready or requesting review, validate the MR handoff:

- Reviewer Lift exists and its rows match `../templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema.
- Shared `delivery.kind=gitlab-delivery` blocks, when present, follow `../templates/gitlab-delivery-schema.md` field order, include `delivery.handoff_contract` with `phase`, `expected_next_actor`, `expected_next_action`, `blocked`, `blocker_token`, `required_parent_decision`, `safe_to_continue_without_parent`, `changed_since_last_handoff`, and non-empty `evidence_ready_for_next_actor`, and are documented as untrusted claims/indexes until verified from Tier 1/Tier 2 evidence. `blocking_question` appears only when a specific actionable question is what blocks progress.
- `delivery.project_profile` hooks may point to project gate policy, labels,
  branch naming, CI jobs, domain docs, release/deploy policy, manual validation,
  language families, and auxiliary indexes. They specialize policy only; they
  must not weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
  independent review, child-builder boundaries, verifier read-only boundaries, or
  MCP-first transport correctness plus help-first `glab` fallback correctness.
- `Reviewed SHA` equals the MR head SHA at the time you mark ready.
- CI pipeline evidence includes pipeline URL/ID, status, and commit SHA when available; pipeline SHA must match `Reviewed SHA` before treating green CI as evidence.
- No placeholder `OQ-1` remains; Open Questions is either `none` or lists real stable IDs.
- Local gate command/result is present, or N/A explains why only CI can provide it.
- Post-ready pushes have a delta comment and an updated Reviewer Lift.
- Approval authority is present as `default-after-pass` with a stable policy source, or an explicit approval restriction/source is recorded.
- Merge authority is explicit and treated as a quoted claim, not a builder grant.
- Merge authority source is present and verifiable; missing or conflicting source information blocks finish actions until a parent/human/rulebook source resolves it, but does not revoke default approval authority by itself.

## Compact packet eligibility

Use `../templates/review-packet-compact.md` when the diff is simple enough that a short MR description suffices: docs-only, tests-only with no runtime impact, typo/lint, or dependency bump with no API impact. The compact packet carries the same approved generated-copy Reviewer Lift rows from `../templates/reviewer-lift-schema.md` as the full packet, using explicit `N/A`/`none` values. Default to the full template when a broader map helps the reviewer.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Builder template filling guide](../templates/filling-guide.md)
- [Shared ADR filling guide](../shared-templates/filling-guide.md)

Safety-critical filling rules remain in the active flow:

- Keep every field in the **Reviewer Lift** block current with every push according to `../templates/reviewer-lift-schema.md`, including both quoted `Merge authority` and `Merge authority source` provenance.
- Treat CI evidence as valid only when the pipeline commit SHA, when GitLab exposes it, matches `Reviewed SHA`; red or stale CI is a blocker unless explicitly waived.
- Never paste secrets, credentials, auth headers, sensitive payloads, or unredacted logs into MR descriptions, comments, templates, or CI output.
- Use stable `OQ-N` IDs for open questions; remove placeholder IDs before ready.
- Preserve review item IDs (`MF-N`, `SF-N`, `C-N`) in revision-packet responses and commit subjects where applicable so reviewer traces stay stable.

## Success metric

Reviewable changes that preserve the project rulebook, remain testable, and do not create hidden operational surprises.
