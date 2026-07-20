# Revision Packet

## Metadata

| Field | Value |
|---|---|
| MR | `<gitlab MR URL>` |
| Responding to | `<originating Review Report stable locator plus posted comment URL when available, CI failure, or post-ready delta note>` |
| Revision # | |
| Branch | |
| Previous reviewed SHA | |
| New commit(s) | |
| New reviewed SHA | `<head SHA after revision push; also update Reviewer Lift in MR description>` |
| Delta since previous reviewed SHA | `<old SHA -> new SHA; reason; changed files; substantive? yes/no>` |
| Gate rerun | `<command + result, or N/A — why>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available>` |

## Summary

## Finding bindings

Repeat the canonical tuple from each originating Review Report for every short ID addressed below. The contract and marker format are owned by `../../start-review/reference/finding-identities.md`. Before publication run `node start-review/scripts/validate-finding-bindings.mjs --report <originating-report.md> ... --packet <this-revision-packet.md>`; missing, stale, ambiguous, or contradictory bindings fail closed.

<!-- FINDING-IDENTITY-SCHEMA:BEGIN -->
| Report locator | Reviewed SHA | Finding ID |
|---|---|---|
| `<stable originating report locator>` | `<exact originating reviewed SHA>` | `<MF-N / SF-N / C-N>` |
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
