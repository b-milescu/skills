# Review Packet (compact)

<!--
Compact variant for simple tasks: docs-only, typo, formatting, tests-only
with no runtime safety impact, or dependency bump with no API/runtime impact.
Paste as the MR description. Delete HTML comments before submitting.
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
| Status | `<draft / ready-for-review>` |

## Reviewer Lift

| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS / FAIL / N/A> — <exact command>` |
| RED | `<N/A — compact/non-behavior, or exact failing command for tests-only behavior>` |
| GREEN | `<passing command + brief result, or N/A — why>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<N/A for single-issue; otherwise list co-running MR IIDs + decoupling reason>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Merge authority | `<approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |

## Summary

<!-- One paragraph: what changed and why. -->

## Scope

### In scope

<!-- Bullet list. -->

### Out of scope

<!-- Usually: "No runtime behavior, external paths, state schema, gates, or domain rules changed." -->

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety Confirmation

- [ ] No PRO external-system mutation path changed.
- [ ] No credential / secret-store handling changed.
- [ ] No domain rule or strategy behavior changed.
- [ ] No state schema, migration, deploy topology, or enforce-mode behavior changed.

## Test Evidence

<!-- Commands run and result, or CI link. State TDD: N/A for compact-eligible non-behavior changes. For docs-only, a targeted markdown/read check may be enough. -->

## Follow-ups

<!-- "None" or linked follow-up issues. -->
