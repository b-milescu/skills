# Review Report

<!--
Reviewer: post this as a single top-level comment on the MR. Use inline review
comments for line-anchored findings, and reference each Must Fix item ID
(MF-1, MF-2, ...) so revision commits can cite them.
Delete HTML comments before submitting; keep section headers stable.
-->

## Metadata

| Field | Value |
|---|---|
| MR | `<gitlab MR URL>` |
| Issue | `<gitlab issue URL>` |
| Reviewer | `<gitlab actor>` — `<exact model id if exposed, e.g. claude-opus-4-7>` |
| Report # | |
| Decision | `<approve / request-changes / reject>` |
| Reviewed SHA | `<copy from builder's Reviewer Lift; must equal MR head sha at approve-time>` |
| CI pipeline (builder reported) | `<copy from Reviewer Lift; verify URL/ID/status/SHA against current pipeline>` |
| CI decision | `<green / pending-auto-merge / waived / blocked-stale-or-red>` |
| Local gate (builder reported) | `<copy from Reviewer Lift>` |
| Builder RED | `<copy from Reviewer Lift>` |
| Builder GREEN | `<copy from Reviewer Lift>` |
| Changed paths | `<copy from Reviewer Lift; verify against diff>` |
| Touched safety surfaces | `<copy from Reviewer Lift; verify against diff>` |
| Decoupling proof verified | `<N/A / accepted as-stated / re-checked: result>` |
| Builder Reviewer Focus | `<copy from Reviewer Lift>` |
| Builder Open Questions | `<copy from Reviewer Lift>` |
| Merge authority | `<copy from Reviewer Lift; default approval-only if absent>` |
| Delta since last ready push | `<copy from Reviewer Lift / N/A; verified against comments>` |
| Merge action | `<merged / auto-merge queued / approval-only / not approved / blocked: reason>` |
| Time spent | |
| Ran code? | `<no / yes: commands>` |

## Summary

<!-- Overall assessment. If requesting changes, state the headline. -->

## Decision

<!-- Approve / Request Changes / Reject. Repeat unambiguously. -->

## Must Fix

<!--
Blocking items. Each item: stable ID, path + line/range, problem, and
suggested direction if not obvious. Prefix credential/security findings with
[SECURITY].
-->

## Should Fix

<!-- Non-blocking but should be addressed. SF-1, SF-2, ... -->

## Consider

<!-- Optional suggestions / preferences / future work. C-1, C-2, ... -->

## Safety Checklist

<!--
Pass/fail/N/A for applicable invariants:
- domain envelope preserved
- product/runtime/operator external-system mutations only via approved adapters
- observe/enforce or dry-run/production gates intact
- protective sequencing intact
- coordination primitive (lease/lock) acquired and not force-stolen
- immutable baselines and monotonic invariants preserved
- exact-decimal numeric type for money/quantity/domain math
- pure engines side-effect free
-->

## State / Migration / Persistence Checklist

<!-- Typed models, atomic writes, append-only migrations, transactional events, CLI/interop contracts. -->

## External-System and Credential Checklist

<!-- No live mutation, adapter-only calls, fake/recorded HTTP tests, redaction, secrets untouched. -->

## Tests and Evidence Reviewed

<!-- Builder evidence accepted/rejected; tests you ran; CI status. Note whether CI pipeline SHA matches Reviewed SHA when GitLab exposes it. -->

## Acceptance Criteria Evidence Checked

<!-- For each acceptance criterion from the MR/issue, state accepted evidence or gap. -->

| Acceptance criterion | Evidence checked | Result |
|---|---|---|
| AC-1 | `<test/command/link/manual evidence>` | `<pass / gap / N/A>` |

## TDD / Behavior-Test Evidence

<!-- Behavior-touching MR: public interface tested? RED/GREEN trace present or reasonably N/A? Tests avoid implementation coupling? Non-behavior MR: "N/A". -->

## Code I Ran

<!-- Exact read-only commands and concise result, or "None". Never paste secrets or run mutating product/runtime/operator commands. -->

## Reviewer Focus Sweep

<!--
What the builder flagged in Reviewer Lift > Reviewer Focus, and what you found
when you read those areas first. "None flagged" if the builder did not name any.
-->

## Open Questions Addressed

<!--
One subsection per OQ-N from the MR description. Either answer it, defer to
human (and say so), or downgrade to an evidence request. Unanswered OQs cannot
sit silently.
-->

None.

<!-- If the builder listed OQ-N IDs, replace "None." with one subsection per question, using this shape:

### OQ-N: <title>

> <quote builder's question>

**Reviewer response:** `<answer / escalate / evidence request>`
-->

## Praise

<!-- Required. Call out good work / patterns to reinforce. -->

## Architectural Observations

<!-- Broader patterns, ADR suggestions, or rejection rationale. -->

## Follow-ups for Other Tasks

<!-- Items not blocking this MR. Open separate issues and link them. -->

## Final Notes

<!-- Short. -->
