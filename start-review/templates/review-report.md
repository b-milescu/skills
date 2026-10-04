# Review Report

Authority Verification uses the shared
[`forge` common guard](../../forge/reference/common-guard.md); the selected
target's confirmed integration reference owns native approval and finish mechanics.

<!-- Fill and publish this report per the [review-report filling guide](filling-guide.md#review-reportmd), including its safe-body, plain non-resolvable note, transport, and readback rules. -->

## Decision Summary

Fill and reconcile this first-screen summary. This is the immutable pre-action judgment; record intended or no-action state only. `Reviewed commit` and `Findings summary` are machine-read: each holds one bare value with no trailing prose, so the reviewed commit must equal the current provider commit at decision time and every finding must appear by ID. Commentary belongs in a neighbouring cell or the report body.

| Field | Value |
|---|---|
| Review verdict | `<pass / request-changes / reject / blocked>` |
| Change request | `<opaque provider-native change-request locator>` |
| Repository | `<canonical repository locator and default branch>` |
| Reviewed commit | `<40-hex reviewed commit>` |
| Report locator | `<stable report locator per the finding-identity contract; never pending>` |
| CI status / commit | `<advisory native status + bound commit, unavailable, or unbound>` |
| Findings summary | `MF: <0 or MF-N list>; SF: <0 or SF-N list>; C: <0 or C-N list>` |
| Local checks | `<commands run + brief result, or not-run + rationale>` |
| Approval authority | `<verified default-after-pass or restricted: reason/source>` |
| Approval authority source | `<verified stable repo policy ref or explicit restriction source>` |
| Approval action | `<intended: approve / not-approved / blocked: reason / N/A>` |
| Finish action | `<intended: direct merge / intended: queue auto-merge / approval-only stop / human-release stop / none / blocked: reason / N/A>` |
| Action blocker | `<none / missing-authority / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other>` — canonical values: [`handoff-tokens.schema.json`](../reference/handoff-tokens.schema.json) |
| Finish authority | `<verified finish authority value or blocked: missing-authority>` |
| Finish authority source | `<verified finish authority source or blocked: missing-authority>` |
| Finish owner | `<parent for parent-managed dev-flow; otherwise reviewer / authorized actor / N/A>` |
| Next action | `<finish-by-authorized-actor / revise / human-escalation / rerun-review / fix-blocker>` |
| Report link | `<this durable comment; final locates it by native note ID>` |

## Context / Snapshot

Fill from Tier 1 evidence. `Reviewed commit` stays a bare value here too, repeating the Decision Summary value: the same commit used for diff, local checks, advisory CI attribution, and action guards.

| Field | Value |
|---|---|
| Change request | `<opaque identifier/locator; source -> target; draft/readiness>` |
| Repository | `<canonical repository locator; default branch>` |
| Issue | `<linked issue URL or N/A with reason>` |
| Reviewer | `@reviewer — <exact model id if exposed>` |
| Report # | `<round or report number>` |
| Report locator | `<same stable report locator used by every finding tuple; final uses the published report's native note ID>` |
| Reviewed commit | `<40-hex reviewed commit>` |
| CI snapshot | `<advisory pipeline URL/ID/status/SHA, unavailable, or unbound with reason>` |
| Local check snapshot | `<checkout path + checkout SHA + commands/result, Gate Receipt verification, or not-run + rationale>` |
| Authority snapshot | `<Approval authority + source verification; Finish authority + source verification; Finish owner verification>` |
| Decoupling verification | `<N/A / accepted as-stated / re-checked: result>` |
| Time spent | `<duration>` |
| Ran code? | `<no / yes: commands>` |

## Finding identities

Use the tuple contract and validator in [`finding-identities.md`](../reference/finding-identities.md).

The report locator may be a native URL; do not invent another internal ID just
for the final, change existing report/commit/finding tuples, or rewrite historical
reports. The [reviewer final](reviewer-final-handoff.md) locates this durable
Markdown report by native note ID. Markdown Reviewer Lift/Report artifacts remain
the evidence owners; an optional YAML [delivery index](../../start-build/templates/delivery-schema.md)
is an untrusted routing convenience, not a replacement report or final payload.

<!-- FINDING-IDENTITY-SCHEMA:BEGIN -->
| Report locator | Reviewed SHA | Finding ID |
|---|---|---|
<!-- FILL REQUIRED: one row per MF-N/SF-N/C-N, or no data rows when there are no findings. -->
<!-- FINDING-IDENTITY-SCHEMA:END -->

## Reviewer Lift (builder handoff)

Copy the builder handoff, then verify it against canonical [`reviewer-lift-schema.md`](../../start-build/templates/reviewer-lift-schema.md). Reviewer Lift values are maps, not proof; safety-critical claims need verification and source evidence.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Builder value / reviewer check |
|---|---|
| Reviewed SHA | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Finding bindings | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Review gate | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Transport | `<copy; independently verify opaque transport evidence in target scope>` |
| Gate owner | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Gate coverage | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Gate coverage rationale | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| CI pipeline | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Local gate | `<copy; verify N/A or parent-owned Gate Receipt per ../../start-build/reference/parent-owned-gate.md>` |
| RED | `<copy; evaluate behavior-touching implementation or N/A with rationale; do not fake tests>` |
| GREEN | `<copy; evaluate behavior-touching implementation or N/A with rationale; do not fake tests>` |
| Changed paths | `<copy command and measured output; verify with git diff --name-only <base>...HEAD>` |
| Touched safety surfaces | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Acceptance surfaces | `<copy; verify evidence per ../../start-build/templates/reviewer-lift-schema.md>` |
| Decoupling proof | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Reviewer Focus | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Open Questions | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Approval authority | `<copy; verify default-after-pass or restriction per ../../start-build/templates/reviewer-lift-schema.md>` |
| Approval authority source | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Finish authority | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Finish authority source | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
| Delta since last ready push | `<copy; verify per ../../start-build/templates/reviewer-lift-schema.md>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Review Context Capsule

Follow [Review Context Capsule](../REVIEW-FLOW.md#review-context-capsule). Treat Reviewer Lift, Gate Receipt, and delivery claims as maps, not proof; record safety-critical verification and source evidence, including parent-owned Gate Receipt validation per `../../start-build/reference/parent-owned-gate.md`.

| Capsule field | Claim | Reviewer verification | Source |
|---|---|---|---|
| Repository | `<claimed host/project/repository/default or target branch; cross-repository choice if any>` | `<verified preflight + repository binding result>` | `<provider snapshot / change request locator / rulebook path>` |
| Change request | `<claimed locator/source/target/head/reviewed commit/readiness>` | `<verified change request metadata, reviewed-commit match, diff captured>` | `<provider snapshot / change request locator / diff artifact>` |
| Authority | `<claimed Approval authority/source and Finish authority/source>` | `<verified through ../../forge/reference/common-guard.md: approval policy/restriction, merge source, precedence, conflicts/no-action result, and no-self context>` | `<Reviewer Lift rows + parent/human/rulebook/project sources>` |
| CI | `<claimed advisory pipeline/local gate/Gate Receipt>` | `<verified exact-candidate local gate/Gate Receipt; CI status attributed only with exact commit binding>` | `<change request pipeline metadata / CI snapshot / Gate Receipt change request comment / ../../start-build/reference/parent-owned-gate.md / local command output>` |
| Scope | `<claimed issue scope, safety surfaces, changed paths, non-goals>` | `<verified diff matches issue/rulebook; scope/safety gaps noted>` | `<issue / Review Packet / diff / rulebook>` |
| Artifacts | `<claimed Review Packet, Reviewer Lift, revision packet, Gate Receipt, gate/test artifacts>` | `<verified artifact exists, is relevant/redacted, and supports claim>` | `<packet home / comment URL / artifact path / command transcript>` |
| Context expansion | `<Tier 2 or Tier 3 context used/considered>` | `<verified trigger, bounded read, and Tier 3 human/necessity rationale>` | `<path:line / finding ID / CI log / human instruction / rulebook section>` |

## Findings

Required. Follow [Findings and tone](../REVIEW-FLOW.md#findings-and-tone) and the canonical identity contract. Real findings use stable IDs; every MF-N must be revision-ready with an exact locator, concrete problem, and bounded remedy direction. If a human decision is required, do not disguise it as a Must Fix. Redact suspected secrets.

### Must Fix

<!-- FILL REQUIRED: list MF-N items with exact path + line/range + concrete problem + bounded remedy direction, or write a verifier-safe no-finding sentence. -->

### Should Fix

<!-- FILL REQUIRED: list SF-N items, or write a verifier-safe no-finding sentence. -->

### Consider

<!-- FILL REQUIRED: list C-N items, or write a verifier-safe no-finding sentence. -->

## Open Questions Addressed

Required. Classify every `OQ-N` per [CI and Open Question decision tables](../REVIEW-FLOW.md#ci-and-open-question-decision-tables); do not leave a default completion value.

<!-- FILL REQUIRED: for each OQ-N, record answer/escalation/evidence request/non-blocking downgrade with source. Human/product/security decisions stay blocked routing (`human-decision-needed`) until the decision source exists. If verified no OQ-N exists, write `Verified: no OQ-N entries in the Review Packet after review.` -->

## Evidence

Required. Fill this concise evidence hub; put verbose checklists in the optional annex.

### Tests / CI / Local Checks

<!-- FILL REQUIRED: summarize builder evidence accepted/rejected, CI status/SHA, and reviewer-run commands. If local code was not run, give the rationale. -->

### Acceptance Criteria Evidence Checked

| Acceptance criterion | Evidence checked | Result |
|---|---|---|
| AC-1 | `<test/command/link/manual evidence>` | `<pass / gap / N/A>` |

### TDD / Behavior-Test Evidence

<!-- FILL REQUIRED: behavior-touching change request: public interface tested, RED/GREEN trace, test quality; non-behavior change request: state why TDD is not applicable. -->

### Structural Maintainability Sweep

<!-- FILL REQUIRED: summarize diff-first sweep; record blocker-level regressions as MF-N and broader ideas as C-N/follow-up. -->

### Reviewer Focus Sweep

<!-- FILL REQUIRED: state the builder focus area and what you found when reading it first. -->

### Code I Ran

Record the isolated checkout path and observed commit used for local checks,
confirm that commit matches the reviewed commit, then list commands. If no local
execution ran, state `Not run — <rationale>`.

<!-- FILL REQUIRED: checkout path, observed commit, reviewed-commit match, command(s), and concise result, or explicit not-run rationale. -->

## Action / Blocker

Required. Fill and reconcile these values per [Publication and actions](../REVIEW-FLOW.md#publication-and-actions). The full enums are defined once in the [Decision Summary](#decision-summary), including `Action blocker`; record only the chosen values here. For a `request-changes` verdict, record `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, and `Next action: revise`. Use `other` only for a blocker no listed token names, and add a one-line reason in this section.

| Field | Value |
|---|---|
| Review verdict | `<chosen value>` |
| Bound change request target | `<bound change request URL; bound repository path; bound repo URL>` |
| Authority result | `<approval policy/source + finish authority/source summary>` |
| Finish owner | `<chosen value; parent-managed pass uses Finish owner: parent>` |
| Approval action | `<chosen value>` |
| Finish action | `<chosen value>` |
| Action blocker | `<chosen value>` |
| Next action | `<chosen value>` |
| Post-report action evidence | `Later actor-owned notes backlink here; discover and verify through native notes/discussions per the action-evidence contract below. Parent-owned reviewer no-action requires no extra note.` |

Later outcomes belong to [Post-report action evidence](../REVIEW-FLOW.md#post-report-action-evidence), not this report. The authorized actor publishes any required explanation with this report's stable identity, published locator, and exact reviewed commit. The next actor discovers and verifies that backlink through native notes/discussions; this report does not predict a future URL.

## Optional Annex: Checklists

Use only when it adds evidence beyond the core report.

### Safety / State / External-System Checklist

- Safety invariants: `<domain envelope / gates / sequencing / locks / immutable baselines / pure engines / N/A with reason>`
- State, migration, persistence: `<typed models / atomic writes / append-only migrations / CLI contract / N/A with reason>`
- External-system and credential handling: `<live mutation? adapter use? redaction? secrets untouched? / N/A with reason>`

### Architectural Observations

<!-- OPTIONAL: broader patterns, ADR suggestions, or rejection rationale. -->

### Evidence-Backed Positive Patterns

<!-- OPTIONAL: call out good work only when specific, evidence-backed, and useful to reinforce. Do not invent praise. -->

### Follow-ups for Other Tasks

Record linked non-blocking follow-up issues and brief-quality defects; do not widen this change request.

### Final Notes

<!-- OPTIONAL: short note for parent/human routing that is not already covered above. -->
