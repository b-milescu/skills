# Review Report

## Decision Summary

Fill this first-screen summary before evidence detail so parent orchestrators can route the result without scanning the full report. `Review verdict` is the review judgment; GitLab side effects are recorded separately in the action fields.

| Field | Value |
|---|---|
| Review verdict | `<pass / request-changes / reject / blocked>` |
| Reviewed SHA | `<sha reviewed; must equal MR head at decision time>` |
| CI status / SHA | `<green / pending-auto-merge / waived / blocked-stale-or-red / blocked-missing; pipeline SHA or N/A>` |
| Findings summary | `MF: <count or IDs>; SF: <count or IDs>; C: <count or IDs>` |
| Local checks | `<commands run + brief result, or not-run + rationale>` |
| Approval action | `<approved / not-approved / blocked: reason / N/A>` |
| Finish action | `<merged / auto-merge queued / approval-only stop / human-release stop / none / blocked: reason / N/A>` |
| Action blocker | `<none / missing-authority / stale-or-missing-ci / changed-head-sha / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / other>` |
| Next action | `<finish-by-authorized-actor / revise / human-escalation / wait-ci / rerun-review / fix-blocker>` |
| Report link | `<this comment; final handoff contains URL when available>` |

## Metadata

| Field | Value |
|---|---|
| MR | `<gitlab MR URL>` |
| Issue | `<gitlab issue URL>` |
| Reviewer | `@reviewer — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Report # | |
| Review verdict | `<pass / request-changes / reject / blocked>` |
| CI decision | `<green / pending-auto-merge / waived / blocked-stale-or-red / blocked-missing>` |
| Decoupling proof verification | `<N/A / accepted as-stated / re-checked: result>` |
| Approval action | `<approved / not-approved / blocked: reason / N/A>` |
| Finish action | `<merged / auto-merge queued / approval-only stop / human-release stop / none / blocked: reason / N/A>` |
| Action blocker | `<none / missing-authority / stale-or-missing-ci / changed-head-sha / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / other>` |
| Next action | `<finish-by-authorized-actor / revise / human-escalation / wait-ci / rerun-review / fix-blocker>` |
| Time spent | |
| Ran code? | `<no / yes: commands>` |

## Reviewer Lift (builder handoff)

Copy these fields from the builder's `Reviewer Lift` block before reading the diff. Field names, order, and required semantics are canonical in `../../start-build/templates/reviewer-lift-schema.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Builder value / reviewer check |
|---|---|
| Reviewed SHA | `<copy from Reviewer Lift; must equal MR head sha at approve-time>` |
| Review gate | `<copy from Reviewer Lift; verify mandatory or documented human bypass>` |
| CI pipeline | `<copy from Reviewer Lift; verify URL/ID/status/SHA against current pipeline>` |
| Local gate | `<copy from Reviewer Lift; PASS, N/A with rationale, or blocker>` |
| RED | `<copy from Reviewer Lift; evaluate TDD applicability>` |
| GREEN | `<copy from Reviewer Lift; evaluate passing evidence>` |
| Changed paths | `<copy from Reviewer Lift; verify against diff>` |
| Touched safety surfaces | `<copy from Reviewer Lift; verify against diff>` |
| Decoupling proof | `<copy from Reviewer Lift; accept/re-check per Decoupling Contract>` |
| Reviewer Focus | `<copy from Reviewer Lift; sweep before full diff>` |
| Open Questions | `<copy from Reviewer Lift; answer every OQ-N>` |
| Merge authority | `<copy from Reviewer Lift; explicit value required; missing/ambiguous = blocker/no approval>` |
| Delta since last ready push | `<copy from Reviewer Lift / N/A; verify against comments>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

## Decision

State the `Review verdict` and the separate Approval action / Finish action / Action blocker / Next action values. Use `blocked` for guard, authority, permission, preflight, SHA, CI, or human-decision blockers that prevent safe approval or finish without representing a code defect.

## Must Fix

## Should Fix

## Consider

## Safety Checklist

## State / Migration / Persistence Checklist

## External-System and Credential Checklist

## Tests and Evidence Reviewed

## Acceptance Criteria Evidence Checked

| Acceptance criterion | Evidence checked | Result |
|---|---|---|
| AC-1 | `<test/command/link/manual evidence>` | `<pass / gap / N/A>` |

## TDD / Behavior-Test Evidence

## Structural Maintainability Sweep

## Code I Ran

## Reviewer Focus Sweep

## Open Questions Addressed

None.

## Praise

## Architectural Observations

## Follow-ups for Other Tasks

List linked follow-up issue URLs here for non-blocking findings that should survive after merge. Use the documented GitLab/local issue workflow and live label vocabulary only; do not widen current MR scope.

Record brief-quality defects here too when the issue brief omitted critical context, acceptance criteria, test strategy, or non-goals. Name the missing fields and any avoidable discovery or rework.

## Final Notes
