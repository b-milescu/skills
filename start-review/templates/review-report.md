# Review Report

## Decision Summary

Fill this first-screen summary before evidence detail so parent orchestrators can route the result without scanning the full report.

| Field | Value |
|---|---|
| Decision | `<approve / request-changes / reject>` |
| Reviewed SHA | `<sha reviewed; must equal MR head at decision time>` |
| CI status / SHA | `<green / pending-auto-merge / waived / blocked-stale-or-red; pipeline SHA or N/A>` |
| Findings summary | `MF: <count or IDs>; SF: <count or IDs>; C: <count or IDs>` |
| Local checks | `<commands run + brief result, or not-run + rationale>` |
| Report link | `<this comment; final handoff contains URL when available>` |

## Metadata

| Field | Value |
|---|---|
| MR | `<gitlab MR URL>` |
| Issue | `<gitlab issue URL>` |
| Reviewer | `@reviewer — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Report # | |
| Decision | `<approve / request-changes / reject>` |
| CI decision | `<green / pending-auto-merge / waived / blocked-stale-or-red>` |
| Decoupling proof verification | `<N/A / accepted as-stated / re-checked: result>` |
| Merge action | `<merged / auto-merge queued / approval-only / not approved / blocked: reason>` |
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

## Code I Ran

## Reviewer Focus Sweep

## Open Questions Addressed

None.

## Praise

## Architectural Observations

## Follow-ups for Other Tasks

## Final Notes
