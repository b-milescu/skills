# Revision Packet

## Metadata

| Field | Value |
|---|---|
| Change request | `<provider-native identifier and locator>` |
| Responding to | `<originating Review Report locator plus provider-published locator, CI failure, or post-ready delta>` |
| Revision # | |
| Branch | |
| Previous reviewed commit | |
| New commit(s) | |
| New reviewed commit | `<current head after revision push; also refresh Reviewer Lift>` |
| Delta | `<old commit -> new commit; reason; changed files; substantive? yes/no>` |
| Gate rerun | `<command + result; parent-owned: not-run — parent-owned; N/A only when no runnable gate>` |
| CI | `<provider-native locator + ID + status + exact commit>` |
<!-- Publish with `forge publish` and require provider-native readback. -->

## Summary

## Invariant closure

Fill from the first blocking finding per [Class-level revision closure](../reference/implementation-flow.md#class-level-revision-closure); omit when no blocking finding applies.

- Failed claim, shared invariant and establishing evidence / unknown conditions:
- Affected consumers, coherent correction and checks:
- Same-invariant recurrence, if any: original and recurring tuples; failed assumption; positive/negative/unknown controls with expected and observed results:

## Accepted capability coverage

Map the complete accepted capabilities to current evidence or remaining gaps, including capabilities outside the reported example. A revision does not reduce accepted scope.

## Finding bindings

Retain every original report/SHA/finding tuple across revisions, including unchanged or unresolved findings, and record each disposition below per `../../start-review/reference/finding-identities.md`. Run `bun <start-review-dir>/scripts/validate-finding-bindings.mjs --report <originating-report.md> ... --packet <this-packet.md>`, where `<start-review-dir>` is the absolute path of `../../start-review` in the installed skill ([helper rule](../../forge/SKILL.md#helpers)). Missing/stale/ambiguous/duplicate/mismatched bindings fail; native scope verification remains separate.

<!-- FINDING-IDENTITY-SCHEMA:BEGIN -->
| Report locator | Reviewed SHA | Finding ID |
|---|---|---|
| `<stable originating report locator>` | `<exact originating reviewed commit>` | `<MF-N / SF-N / C-N>` |
<!-- FINDING-IDENTITY-SCHEMA:END -->

## Response to Must Fix

### MF-1: <title>

> <quote from report>

**Response:**

**Commit:**

## Response to Should Fix

## Response to Consider

## What I did not change

## Updated Safety Impact

## Updated State / Migration / External-System Evidence

## Updated Test Evidence

Bind updated evidence and Reviewer Lift to the new head; earlier gate/receipt/review evidence is historical. Preserve gate/finish ownership: fresh exact-candidate gate evidence precedes ready/re-review, and fresh independent review precedes approval/finish.

## Diff Since Previous Review

## Open Questions (Unresolved)

## Reviewer Hints for This Round
