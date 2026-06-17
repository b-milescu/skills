# Review Report

<!-- Post this filled report as one top-level plain (non-resolvable) MR note through canonical file-backed `gitlab` Snippet: mr-note-create (`mr_note_create --message-file`). Large Review Report bodies MUST NOT be posted inline via MCP `create_merge_request_note` strings. Read back the created MR note and verify body matches this source report file/content before it counts as durable/posted; placeholder/partial/literal-expansion/body-mismatch notes fail closed: repost file-backed or record transport blocker. Do NOT post discussion thread — Review Report informational must never leave unresolved thread blocks merge. Only genuine change-request threads (Must Fix / Should Fix items builder must answer) should remain open resolvable discussions. If report accidentally posted resolvable thread, resolve it immediately. -->

## Decision Summary

Fill this first-screen summary before evidence detail so parent orchestrators can route the result without scanning the full report. `Review verdict` is the review judgment; GitLab side effects are recorded separately in the action fields. When the report is posted before GitLab actions, action fields must distinguish intended action from completed action; completed approval/merge/queue results belong in the final handoff or an action-result note after verification.

Source-of-truth note: copy these values from the final `Context / Snapshot`, `Findings`, `Evidence`, and `Action / Blocker` sections. Do not maintain separate facts here.

| Field | Value |
|---|---|
| Review verdict | `<pass / request-changes / reject / blocked>` |
| Bound MR target | `<bound MR URL; bound MR project path; bound repo URL>` |
| Reviewed SHA | `<sha reviewed; must equal MR head at decision time>` |
| CI status / SHA | `<green / pending-auto-merge / waived / blocked-stale-or-red / blocked-missing; pipeline SHA or N/A>` |
| Findings summary | `MF: <count or IDs>; SF: <count or IDs>; C: <count or IDs>` |
| Local checks | `<commands run + brief result, or not-run + rationale>` |
| Approval authority | `<verified default-after-pass or restricted: reason/source>` |
| Approval authority source | `<verified stable repo policy ref or explicit restriction source>` |
| Approval action | `<intended: approve / approved only after verified / not-approved / blocked: reason / N/A>` |
| Finish action | `<intended: direct merge / intended: queue auto-merge / merged only after verified / auto-merge queued only after verified / approval-only stop / human-release stop / none / blocked: reason / N/A>` |
| Action blocker | `<none / missing-authority / stale-or-missing-ci / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other>` |
| Merge authority | `<verified finish authority value or blocked: missing-authority>` |
| Merge authority source | `<verified finish authority source or blocked: missing-authority>` |
| Next action | `<finish-by-authorized-actor / revise / human-escalation / wait-ci / rerun-review / fix-blocker>` |
| Report link | `<this comment; final handoff contains URL when available>` |

## Context / Snapshot

Use this compact snapshot as the source of truth for repeated critical fields in the Decision Summary. Verify every row from Tier 1 evidence before relying on it for verdict or action.

| Field | Value |
|---|---|
| MR | `<bound MR URL; IID; source -> target; draft/readiness>` |
| Bound project/repo | `<host/project path; explicit repo target used for commands>` |
| Issue | `<linked issue URL or N/A with reason>` |
| Reviewer | `@reviewer — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Report # | `<round or report number>` |
| Reviewed SHA | `<same SHA used for diff, local checks, CI classification, and action guards>` |
| CI snapshot | `<pipeline URL/ID/status/SHA or N/A with reason>` |
| Local check snapshot | `<checkout path + checkout SHA + commands/result, Gate Receipt verification, or not-run + rationale>` |
| Authority snapshot | `<Approval authority + source verification; Merge authority + source verification>` |
| Decoupling verification | `<N/A / accepted as-stated / re-checked: result>` |
| Time spent | `<duration>` |
| Ran code? | `<no / yes: commands>` |

## Reviewer Lift (builder handoff)

Copy these fields from the builder's `Reviewer Lift` block before reading the diff. Field names, order, and required semantics are canonical in `../../start-build/templates/reviewer-lift-schema.md`; authority verification is canonical in `../../gitlab/reference/authority-verification.md`; parent-owned Gate Receipt verification is canonical in `../../start-build/reference/parent-owned-gate.md`. Treat copied values, Gate Receipt comments, and any compact `delivery.kind=gitlab-delivery` fields as claims until the `Review Context Capsule` verifies them from Tier 1/Tier 2 evidence.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Builder value / reviewer check |
|---|---|
| Reviewed SHA | `<copy from Reviewer Lift; must equal MR head sha at approve-time>` |
| Review gate | `<copy from Reviewer Lift; verify mandatory or documented human bypass>` |
| Gate owner | `<copy from Reviewer Lift; verify builder vs parent ownership and parent-owned child boundary when applicable>` |
| Gate coverage | `<copy from Reviewer Lift; verify full-local / hybrid / ci-only; parent-owned is invalid coverage>` |
| Gate coverage rationale | `<copy from Reviewer Lift; verify policy source, required CI mapping, unmapped CI-only jobs or none, and exact-SHA freshness>` |
| CI pipeline | `<copy from Reviewer Lift; verify URL/ID/status/SHA against current pipeline>` |
| Local gate | `<copy from Reviewer Lift; PASS before ready/review is sufficient only for full-local coverage, N/A with rationale, or not-run parent-owned with Gate Receipt verification per ../../start-build/reference/parent-owned-gate.md; hybrid/ci-only requires exact-SHA CI success for uncovered required jobs or waiver; otherwise blocker>` |
| RED | `<copy from Reviewer Lift; evaluate behavior-touching implementation RED evidence or N/A with rationale; do not fake tests>` |
| GREEN | `<copy from Reviewer Lift; evaluate behavior-touching implementation GREEN evidence or N/A with rationale; do not fake tests>` |
| Changed paths | `<copy from Reviewer Lift; verify against diff>` |
| Touched safety surfaces | `<copy from Reviewer Lift; verify against diff>` |
| Acceptance surfaces | `<copy from Reviewer Lift; verify each declared surface has test, smoke, docs-read, ci, or documented N/A evidence; surfaces without evidence or undeclared touched surfaces are MF-N blockers before pass>` |
| Decoupling proof | `<copy from Reviewer Lift; accept/re-check per Decoupling Contract>` |
| Reviewer Focus | `<copy from Reviewer Lift; sweep before full diff>` |
| Open Questions | `<copy from Reviewer Lift; answer every OQ-N>` |
| Approval authority | `<copy approval policy claim; default-after-pass unless explicitly restricted; verify before approval>` |
| Approval authority source | `<copy approval policy/restriction source; stable repo policy ref allowed; separate from merge authority>` |
| Merge authority | `<copy quoted finish-authority claim from Reviewer Lift; explicit value required before merge/auto-merge/release/close>` |
| Merge authority source | `<copy from Reviewer Lift; verify before finish action; missing/unverifiable blocks finish but does not override default approval authority>` |
| Delta since last ready push | `<copy from Reviewer Lift / N/A; verify against comments>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Review Context Capsule

Use Reviewer Lift, Gate Receipt comments, and compact delivery fields as maps, not truth. Parent-owned Gate Receipt verification uses `../../start-build/reference/parent-owned-gate.md`. For every safety-critical field, record reviewer verification and source before relying on a claim for the verdict or any approval/finish action.

| Capsule field | Claim | Reviewer verification | Source |
|---|---|---|---|
| Repo | `<claimed host/project/repo/default or target branch; cross-repo choice if any>` | `<verified preflight + project binding result>` | `<repo command output / MR URL / rulebook path>` |
| MR | `<claimed MR IID/URL/source/target/head/reviewed SHA/readiness>` | `<verified MR metadata, Reviewed SHA match, diff captured>` | `<mr-pickup output / MR URL / diff artifact>` |
| Authority | `<claimed Approval authority/source and Merge authority/source>` | `<verified through ../../gitlab/reference/authority-verification.md: approval policy/restriction, merge source, precedence, conflicts/no-action result, and no-self context>` | `<Reviewer Lift rows + parent/human/rulebook/project sources>` |
| CI | `<claimed pipeline/local gate/Gate Receipt>` | `<verified exact-SHA CI decision and local-gate or canonical Gate Receipt status>` | `<MR pipeline metadata / ci snapshot / Gate Receipt MR comment / ../../start-build/reference/parent-owned-gate.md / local command output>` |
| Scope | `<claimed issue scope, safety surfaces, changed paths, non-goals>` | `<verified diff matches issue/rulebook; scope/safety gaps noted>` | `<issue / MR description / diff / rulebook>` |
| Artifacts | `<claimed Review Packet, Reviewer Lift, revision packet, Gate Receipt, gate/test artifacts>` | `<verified artifact exists, is relevant/redacted, and supports claim>` | `<MR description/comment URL / artifact path / command transcript>` |
| Context expansion | `<Tier 2 or Tier 3 context used/considered>` | `<verified trigger, bounded read, and Tier 3 human/necessity rationale>` | `<path:line / finding ID / CI log / human instruction / rulebook section>` |

## Findings

Required. Use stable IDs only for real findings. Each `MF-N` must be revision-ready: exact path + line/range locator, concrete problem, and bounded remedy direction. If a human/product/security decision is still required, do not disguise it as a Must Fix; use `Review verdict: blocked`, `Action blocker: human-decision-needed`, and a specific actionable blocker question instead. For suspected credential exposure, do not quote the secret; write `[SECURITY] Potential secret exposure at path:line; value [REDACTED]` and use `Action blocker: secret-exposure-suspected`.

### Must Fix

<!-- FILL REQUIRED: list MF-N items with exact path + line/range + concrete problem + bounded remedy direction, or write a verifier-safe no-finding sentence. -->

### Should Fix

<!-- FILL REQUIRED: list SF-N items, or write a verifier-safe no-finding sentence. -->

### Consider

<!-- FILL REQUIRED: list C-N items, or write a verifier-safe no-finding sentence. -->

## Open Questions Addressed

Required. Classify every `OQ-N` from the MR description with `../REVIEW-FLOW.md` [CI and Open Question decision tables](../REVIEW-FLOW.md#ci-and-open-question-decision-tables). Do not leave a default completion value.

<!-- FILL REQUIRED: for each OQ-N, record answer/escalation/evidence request/non-blocking downgrade with source. Human/product/security decisions stay blocked routing (`human-decision-needed`) until the decision source exists. If verified no OQ-N exists, write `Verified: no OQ-N entries in the MR description after review.` -->

## Evidence

Required. Keep this concise and evidence-first; put verbose checklists in the optional annex.

### Tests / CI / Local Checks

<!-- FILL REQUIRED: summarize builder evidence accepted/rejected, CI status/SHA, and reviewer-run commands. If local code was not run, give the rationale. -->

### Acceptance Criteria Evidence Checked

| Acceptance criterion | Evidence checked | Result |
|---|---|---|
| AC-1 | `<test/command/link/manual evidence>` | `<pass / gap / N/A>` |

### TDD / Behavior-Test Evidence

<!-- FILL REQUIRED: behavior-touching MR: public interface tested, RED/GREEN trace, test quality; non-behavior MR: state why TDD is not applicable. -->

### Structural Maintainability Sweep

<!-- FILL REQUIRED: summarize diff-first sweep; record blocker-level regressions as MF-N and broader ideas as C-N/follow-up. -->

### Reviewer Focus Sweep

<!-- FILL REQUIRED: state the builder focus area and what you found when reading it first. -->

### Code I Ran

Record checkout path and checkout SHA used for local checks before listing commands. If no local execution was run, state `Not run — <rationale>`.

<!-- FILL REQUIRED: checkout path, checkout SHA, command(s), and concise result, or not-run rationale. -->

## Action / Blocker

Required. State the `Review verdict`, bound MR URL/project, verified Approval authority / Approval authority source, verified Merge authority / Merge authority source, and the separate Approval action / Finish action / Action blocker / Next action values. Verify authority through `../../gitlab/reference/authority-verification.md`: use `blocked` for guard, authority, permission, preflight, SHA, CI, partial-review, secret-exposure-suspected, project-binding mismatch, or human-decision blockers that prevent safe approval or finish without representing a code defect. Missing merge authority blocks finish actions; it does not revoke default approval authority after a pass unless an explicit approval restriction source says so. When a missing human/product/security decision is the blocker, keep it here with `human-decision-needed` instead of routing it as builder revision work.

Record the chosen value for each field; the full enums are defined once in the [Decision Summary](#decision-summary) above (`Review verdict`, `Approval action`, `Finish action`, `Action blocker`, `Next action`). Keep the two copies in sync.

| Field | Value |
|---|---|
| Review verdict | `<chosen value>` |
| Bound MR target | `<bound MR URL; bound MR project path; bound repo URL>` |
| Authority result | `<approval policy/source + merge authority/source summary>` |
| Approval action | `<chosen value>` |
| Finish action | `<chosen value>` |
| Action blocker | `<chosen value>` |
| Next action | `<chosen value>` |
| Post-report action note | `<N/A, or URL/summary for approval/finish failure, changed-head-sha, or completed action result>` |

## Optional Annex: Checklists

Use these compact subsections only when they add evidence beyond the core report. Avoid forced praise or invented positive feedback; if no evidence-backed positive pattern matters, omit that subsection or write `No evidence-backed positive pattern called out.`

### Safety / State / External-System Checklist

- Safety invariants: `<domain envelope / gates / sequencing / locks / immutable baselines / pure engines / N/A with reason>`
- State, migration, persistence: `<typed models / atomic writes / append-only migrations / CLI contract / N/A with reason>`
- External-system and credential handling: `<live mutation? adapter use? redaction? secrets untouched? / N/A with reason>`

### Architectural Observations

<!-- OPTIONAL: broader patterns, ADR suggestions, or rejection rationale. -->

### Evidence-Backed Positive Patterns

<!-- OPTIONAL: call out good work only when specific, evidence-backed, and useful to reinforce. Do not invent praise. -->

### Follow-ups for Other Tasks

List linked follow-up issue URLs here for non-blocking findings that should survive after merge. Use the documented GitLab/local issue workflow and live label vocabulary only; do not widen current MR scope.

Record brief-quality defects here too when the issue brief omitted critical context, acceptance criteria, test strategy, or non-goals. Name the missing fields and any avoidable discovery or rework.

### Final Notes

<!-- OPTIONAL: short note for parent/human routing that is not already covered above. -->
