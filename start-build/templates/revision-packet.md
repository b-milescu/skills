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
| Gate rerun | `<command + result, or N/A — why>` |
| CI | `<provider-native locator + ID + status + exact commit>` |
<!-- Publish with `forge publish` and require provider-native readback. -->

## Summary

## Finding bindings

Repeat the canonical tuple from each originating Review Report for every short ID addressed below. The contract and marker format are owned by `../../start-review/reference/finding-identities.md`. Before publication run `node start-review/scripts/validate-finding-bindings.mjs --report <originating-report.md> ... --packet <this-revision-packet.md>`; missing, stale, ambiguous, or contradictory bindings fail closed.

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

## Diff Since Previous Review

## Open Questions (Unresolved)

## Reviewer Hints for This Round
