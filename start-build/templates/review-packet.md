# Review Packet

<!--
Builder: paste this as the MR description for every non-trivial task. Keep it
in sync with the diff as you push. Delete HTML comments before submitting;
keep section headers stable so the Reviewer can scan quickly.
-->

## Metadata

| Field | Value |
|---|---|
| Issue | `<gitlab issue URL>` |
| Title | |
| Builder | `<gitlab actor>` — `<exact model id if exposed, e.g. claude-opus-4-7>` |
| Branch | |
| Base commit | |
| Commit(s) under review | |
| Status | `<draft / ready-for-review / stuck>` |
| ADR needed? | `<yes/no; planned ADR slug if yes>` |
| Blocks | |
| Blocked by | |

## Reviewer Lift

<!--
Structured handoff so the Reviewer can copy these values directly into the
Review Report. Keep current with each push. If you push commits AFTER marking
ready, post a delta comment (old SHA -> new SHA, reason, changed files, gate
rerun, substantive? yes/no) and update this block.
-->

| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS / FAIL / N/A> — <exact command, e.g. make check>` |
| RED | `<exact failing test command + expected failure reason, or N/A — why>` |
| GREEN | `<exact passing test command + brief result, or N/A — why>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<N/A for single-issue; otherwise: list co-running MR IIDs and why decoupled — file/module overlap none, no shared migrations/locks/lockfiles, tests independent>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Merge authority | `<approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |

## Summary

<!-- One paragraph: what changed, why, and the observable effect on users/operators. -->

## Pre-Work Checklist

- [ ] Linked issue and any prior reviews/ADRs read.
- [ ] Project rulebook (top-level operating rules) read for applicable safety rules.
- [ ] Architecture / design docs read for affected surfaces.
- [ ] Domain rulebook read where relevant.
- [ ] Product/runtime/operator external-system mutation surface identified: `<none / read-only / mutating; explain>`
- [ ] Credential/secret exposure surface identified: `<none / config / logging / deploy; explain>`
- [ ] State / schema / migration impact identified: `<none / which stores / which migrations>`
- [ ] Refactor behavior-touching assessment: `<N/A or evidence plan>`
- [ ] TDD applicability/tracer-bullet behavior identified: `<N/A or behavior + expected RED failure>`

## Scope

### In scope

<!-- Bullet list of intended and actual changes. -->

### Out of scope

<!-- Explicitly name adjacent work not done. Open separate issues for follow-ups. -->

## Acceptance Criteria Evidence

<!-- Map issue acceptance criteria to proof so the reviewer can validate scope quickly. -->

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety Impact

<!--
Address every applicable invariant; write N/A with reason for non-applicable items:
- approved domain envelope (no new venues, scopes, capabilities, or rules)
- observe vs enforce / dry-run vs production semantics
- protective sequencing (e.g. cancel-before-replace, classify-before-continue)
- coordination primitives (lease/lock acquired and verified; no force-steal)
- immutable baselines and monotonic invariants
- exact-decimal numeric type for money/quantity/domain math
- pure engines remain side-effect free
-->

## Architecture / Design Decisions

<!-- Decision, alternatives considered, why this shape won, trade-offs to review. Link to ADR if one is required. -->

## State, Persistence, and Migration Impact

<!--
State stores, typed models, DB migrations, event/intent stores, CLI stdout
contracts, cross-language interop. Include migration numbers and smoke-test plan.
Write N/A if none.
-->

## External-System and Credential Safety

<!--
State whether any live product/runtime/operator external mutations were made
(default: no). For changes touching external integrations, explain adapter use,
fake/recorded HTTP tests, redaction, and idempotency keys. Confirm secret stores
were not read/printed/committed.
-->

## Diff Summary

<!-- High-level diffstat and map by file. -->

## Test Evidence

<!--
Expand on the RED/GREEN one-liners in the Reviewer Lift. Include targeted
tests, full check gate output (or CI link), coverage where the project
requires it. For behavior-touching refactors, provide regression evidence.
If red-first evidence is unavailable, explain why and provide equivalent
behavior evidence.
-->

## Manual / Operational Evidence

<!-- Optional. Dry-run output, runbook check, read-only operator command. Never paste secrets. -->

## Concerns / Reviewer Focus

<!-- What could go wrong and where the Reviewer should look hardest. Mirror the headline in Reviewer Lift > Reviewer Focus. -->

## Open Questions

None.

<!--
If reviewer/human input can change direction, replace "None." with stable IDs
so the reviewer can answer/escalate each one in their report. Use headings like:

### OQ-N: <title>
Question + what would change based on the answer.
-->

## Follow-ups

<!-- Linked issues for deferred items, or "None". -->

## Reviewer Hints

<!-- Suggested files/tests to inspect first. Courtesy, not instruction. -->
