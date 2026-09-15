# Template Filling Guide — Start Review

Instruction that the reviewer templates do not already carry inline. Each template owns its own per-section prose; this guide holds only what has no point of use inside a template.

## reviewer-final-handoff.md

- Never include secrets, raw private payloads, or unredacted logs. For suspected secret exposure, do not quote the secret or credential, do not copy the sensitive payload, and use `[REDACTED]` plus `secret-exposure-suspected` without secret values. Use synthetic URLs/SHAs in examples.

## review-report.md

- Post a single top-level **plain, non-resolvable note** through `forge publish`: validate the full body with safe body validation before posting, then read the published artifact back and confirm it matches the source report before treating the report as durable. Placeholder, partial, literal-expansion, or body-mismatched notes fail closed — repost or record the transport blocker, and never approve or finish on a non-durable report. Apply [Findings and tone](../REVIEW-FLOW.md#findings-and-tone) to optional comments and existing threads, including accidentally resolvable reports; line-anchored requirement comments cite their finding tuple or `OQ-N`.
- The core report is concise and summary-first: `Decision Summary`, `Context / Snapshot`, `Finding identities`, `Reviewer Lift (builder handoff)`, `Review Context Capsule`, `Findings`, `Open Questions Addressed`, `Evidence`, and `Action / Blocker`. Long checklists live in `Optional Annex: Checklists` and should stay compact.
- **Decision Summary** — Draft before the final guards, then refresh after the final change-request/CI/authority snapshot and before posting. Review verdict (`pass / request-changes / reject / blocked`), Report locator, reviewed commit, CI status / commit, MF-N/SF-N/C-N findings, local checks, Approval action, Finish action, Action blocker, and Next action all copy from the core sections.
- **Reviewer Lift (builder handoff)** — Copy every field before reading the diff; `../../start-build/templates/reviewer-lift-schema.md` owns field names, order, and required semantics. Treat Reviewer Lift and any Gate Receipt as maps, not proof: verify each copied value against change-request metadata, diff, comments, Gate Receipt source fields, and advisory CI, and give every safety-critical field its own reviewer verification and source. Classify CI only as an advisory observation per `../REVIEW-FLOW.md` [CI and Open Question decision tables](../REVIEW-FLOW.md#ci-and-open-question-decision-tables).
- **Findings** — Follow `../REVIEW-FLOW.md` [Findings and tone](../REVIEW-FLOW.md#findings-and-tone) and `../reference/finding-identities.md`; keep each finding revision-ready with its `(Report locator, Reviewed SHA, Finding ID)`, include a bounded remedy direction, and write an explicit verifier-safe sentence for an empty bucket.
- **Approval authority / Approval authority source** — Follow `../REVIEW-FLOW.md` [Approval-authority policy](../REVIEW-FLOW.md#approval-authority-policy); record `Approval authority: default-after-pass` and its verified source, or the stronger restriction.
- **Finish authority / Finish authority source** — Follow `../REVIEW-FLOW.md` [Finish authority source precedence](../REVIEW-FLOW.md#finish-authority-source-precedence) for the explicit Finish claim and its verified source.
- **Acceptance Criteria Evidence Checked** — For each acceptance criterion from the change request/issue, state accepted evidence or gap. **AC artifact-naming rule:** when an AC names a produced evidence artifact (tabulated diff, recorded identification, note posted at a named location, or any other deliverable at a specific path or comment), the AC is satisfied only by that artifact existing at the named location; prior-work references, indirect validation, or plausibility arguments do not satisfy it. Record the artifact location verified or the gap if the artifact is absent.
- **Code I Ran** — Record the isolated checkout path and observed commit used for local checks, and confirm it matches the reviewed commit before listing commands. If no local execution ran, state `Not run — <rationale>`. Never paste secrets or run mutating product/runtime/operator commands.
- **Action / Blocker** — Keep verdict, approval, finish, blocker, and next actor/action separate. An action-only failure before or after publication does not change a valid judgment; a review-invalidating failure still prevents pass. For a `request-changes` verdict, record `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, and `Next action: revise`.
- **Action blocker** — Use `none` or a stable token: `missing-authority`, `changed-head-sha`, `merge-conflict`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or `other`. CI status is not a blocker. Use `other` only for a blocker no listed token names, and add a one-line reason in **Action / Blocker**. Canonical values are owned by [`handoff-tokens.schema.json`](../reference/handoff-tokens.schema.json).
- **Follow-ups for Other Tasks** — Items not blocking this change request. Open separate issues and link them when a `C-N` or other non-blocking finding should survive after merge. Record brief-quality defects here too when the issue brief omitted critical context, acceptance criteria, test strategy, or non-goals; name the missing fields and the avoidable discovery or rework. Use only the documented provider/local issue workflow and live label vocabulary.

## unblock-response.md

- Use when responding to a Stuck Packet. Post as a change-request comment with `forge publish`. When Builder resumes, remove the project's unblock label if one exists.
- **Engagement with hypotheses** — Respond to each ranked hypothesis (`H-N`) the builder listed in the Stuck Packet, one subsection per hypothesis: confirm, refute, refine, or defer it with the evidence or check that backs your call.
- **Direction** — Pointer / correction / pair / escalation. Cite files, tests, docs, or commands.
- **Safety notes** — Any product/runtime/operator external-system / credential / state precautions before continuing.
- **What I did not check** — Honest scope. **Confidence** — High / medium / low and why.

## adr.md

See the [shared ADR filling guide](../shared-templates/filling-guide.md) for ADR template filling instructions.
