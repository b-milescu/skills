# Review Packet (compact)

For docs-only, tests-only with no runtime safety impact, typo/lint, or a
dependency bump with no API/runtime impact. `filling-guide.md`
(review-packet-compact.md) owns eligibility and section instructions.

## Metadata

| Field | Value |
|---|---|
| Work item | `<provider-native identifier and locator>` |
| Change request | `<provider-native identifier and locator>` |
| Title | |
| Builder | `@builder — <exact model id if exposed>` |
| Branch | |
| Base commit | |
| Current/reviewed commit(s) | |

Before publication or a ready transition, use the selected `/forge` provider to
validate the native work-item relationship/closure preview and require
provider-native publication readback. Missing, incomplete, stale, or mismatched
evidence fails closed.

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`; parent-owned Gate Receipt / Check Gate ownership is canonical in `../reference/parent-owned-gate.md`.

Before a parent-owned ready transition, validate the canonical receipt and this
current Reviewer Lift with `skill://start-build/scripts/validate-gate-receipt.mjs`,
supplying `--gate-receipt-locator "<opaque current Gate Receipt locator>"`.

Before publication or a ready transition, validate every non-`none` `Finding bindings` tuple against the originating Review Report files with `node start-review/scripts/validate-finding-bindings.mjs --report <report.md> ... --lift <this-review-packet.md>` per `../../start-review/reference/finding-identities.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<change-request head commit at ready-marking; update on every post-ready push>` |
| Finding bindings | `<none, or report=<stable report locator>; sha=<originating reviewed commit>; id=<MF-N/SF-N/C-N>; separate multiple tuples with <br>; validate against originating reports before publication/ready>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| Transport | `<build-side mutation transport; one of mcp / glab-fallback (gap: <named MCP gap from gitlab/SKILL.md>) / n/a; matches finish-result-schema transport enum; defaults to mcp when absent>` |
| Gate owner | `<builder / parent; parent-owned child records parent-owned/not-run and candidate SHA only>` |
| Gate coverage | `<full-local / hybrid / ci-only; never parent-owned>` |
| Gate coverage rationale | `<policy source + required CI mapping; unmapped CI-only jobs or none; stale/wrong-SHA evidence invalid after push>` |
| CI pipeline | `<provider-native CI locator + ID + status + commit when available, or N/A — why>` |
| Local gate | `<PASS / FAIL while draft / N/A — why / not-run — parent-owned per ../reference/parent-owned-gate.md with Gate Receipt pending; completed local gate or parent Gate Receipt permits review launch for every coverage class; hybrid/ci-only may launch with exact-commit CI pending, but failed/canceled/skipped/missing/stale/wrong-commit CI blocks pass and finish unless waived> — <exact command>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `git diff --name-only <base>...HEAD` — measured output: `<one path per line, separated with <br>>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / wire-protocol / other>` |
| Acceptance surfaces | `<none, or per-surface evidence; allowed surfaces come from project_profile.acceptance_surfaces_ref (no ref ⇒ none); evidence enum: test/smoke/docs-read/ci/N/A; compact syntax: surface:evidence — e.g. docs:docs-read, prompt:test; each declared surface must have test/smoke/docs-read/ci/N/A evidence before ready/pass>` |
| Decoupling proof | `<single change request, or co-running change-request identifiers/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Approval authority | `<default-after-pass / restricted: source-or-reason>` |
| Approval authority source | `<stable repo policy ref / parent task prompt / human or provider discussion locator / project rulebook path+section>` |
| Finish authority | `<quoted claim; defaults to none — requires explicit human/parent instruction; a granting value needs an affirmative quoted grant in the source>` |
| Finish authority source | `<parent task prompt / human discussion locator / rulebook path+section / project default source; a disclaiming or silent source forces the none default>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

One paragraph: what changed and why. Name loaded context sources beyond the
issue and rulebook index, or write `none beyond issue and rulebook index`.

## Scope

- **In scope:**
- **Out of scope:** `<usually: no runtime behavior, external paths, state schema, gates, or domain rules changed>`

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |
| AC-N literal string: `<quoted target text>` | `<exact-string comparison evidence against current head SHA; only when this criterion is byte-for-byte wording-sensitive>` |

## Safety Confirmation

`<Confirm none changed: product/runtime/operator external-system mutation path;
credential / secret-store handling; domain rule or strategy behavior; state
schema, migration, deploy topology, or enforce-mode behavior. Note any exception.>`

## Test Evidence

Commands run and result, or CI link. State `TDD: N/A — <reason>` for
compact-eligible non-behavior changes. A targeted markdown/read check may be
enough for docs-only work.

## Follow-ups

`None` or linked follow-up issues.
