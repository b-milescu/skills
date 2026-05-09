# Revision Packet

<!--
Submit in response to a Review Report requesting changes, or for any
substantive post-ready push after review has started. Post as a single MR
comment summarising the response/delta, with the actual fixes pushed as new
commits on the MR branch (each commit subject naming the item ID when
applicable, e.g. "MF-1: ..."). Update the MR description and Reviewer Lift
with the revision summary so reviewers see it first.
Delete HTML comments before submitting; keep section headers stable.
-->

## Metadata

| Field | Value |
|---|---|
| MR | `<gitlab MR URL>` |
| Responding to | `<link to Review Report MR comment, CI failure, or post-ready delta note>` |
| Revision # | |
| Branch | |
| Previous reviewed SHA | |
| New commit(s) | |
| New reviewed SHA | `<head SHA after revision push; also update Reviewer Lift in MR description>` |
| Delta since previous reviewed SHA | `<old SHA -> new SHA; reason; changed files; substantive? yes/no>` |
| Gate rerun | `<command + result, or N/A — why>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available>` |
| Status | `ready-for-review` |

## Summary

<!-- One paragraph: what changed in response to review/post-ready delta and what stayed the same. -->

## Response to Must Fix

<!-- One subsection per MF item. Quote the headline/snippet, then response and commit SHA. -->

### MF-1: <title>

> <quote from report>

**Response:**

**Commit:**

## Response to Should Fix

<!-- Same shape; use SF IDs. -->

## Response to Consider

<!-- Same shape; valid to decline with reasoning. -->

## What I did not change

<!-- Reviewer comments not acted on, and why. -->

## Updated Safety Impact

<!-- New/changed safety evidence since prior packet, or "No change." -->

## Updated State / Migration / External-System Evidence

<!-- If applicable. Confirm no live product/runtime/operator external mutation and no credential exposure. -->

## Updated Test Evidence

<!-- Re-run gates and targeted tests; CI link or concise output. -->

## Diff Since Previous Review

<!-- High-level diffstat for revision-only changes. -->

## Open Questions (Unresolved)

<!-- Anything still needing reviewer/human decision. -->

## Reviewer Hints for This Round

<!-- Where to inspect first. -->
