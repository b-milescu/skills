# Review Packet (compact)

## Metadata

| Field | Value |
|---|---|
| Issue | `<gitlab issue URL>` |
| Title | |
| Builder | `@builder — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Branch | |
| Base commit | |
| Commit(s) under review | |
| Status | `<draft / ready-for-review>` |

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS before ready/review / FAIL while draft / N/A — why> — <exact command>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<single MR, or co-running MR IIDs/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Merge authority | `<quoted claim: approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Merge authority source | `<parent task prompt / human MR comment URL / rulebook path+section / project default source>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

## Loaded Context Sources

List only sources loaded beyond the issue and rulebook index. Use one-line bullets with why relevant; write `none beyond issue and rulebook index` when no expansion was needed.

## Scope

### In scope

### Out of scope

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety Confirmation

- [ ] No product/runtime/operator external-system mutation path changed.
- [ ] No credential / secret-store handling changed.
- [ ] No domain rule or strategy behavior changed.
- [ ] No state schema, migration, deploy topology, or enforce-mode behavior changed.

## Test Evidence

## Follow-ups
