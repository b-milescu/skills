# Review Packet

## Metadata

| Field | Value |
|---|---|
| Issue | `<gitlab issue URL>` |
| Title | |
| Builder | `@builder — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Branch | |
| Base commit | |
| Commit(s) under review | |
| Status | `<draft / ready-for-review / stuck>` |
| ADR needed? | `<yes/no; planned ADR slug if yes>` |
| Blocks | |
| Blocked by | |

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS / FAIL / N/A> — <exact command, e.g. make check>` |
| RED | `<exact failing test command + expected failure reason, or N/A — why>` |
| GREEN | `<exact passing test command + brief result, or N/A — why>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<single MR, or co-running MR IIDs/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Merge authority | `<quoted claim: approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Merge authority source | `<parent task prompt / human MR comment URL / rulebook path+section / project default source>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

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

### Out of scope

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety Impact

## Architecture / Design Decisions

## State, Persistence, and Migration Impact

## External-System and Credential Safety

## Diff Summary

## Test Evidence

## Manual / Operational Evidence

## Concerns / Reviewer Focus

## Open Questions

None.

## Follow-ups

## Reviewer Hints
