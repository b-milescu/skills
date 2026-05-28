# Template Filling Guide — Start Review

This guide holds instructional prose for reviewer templates. Read once per session; the templates themselves are bare skeletons.

## reviewer-final-handoff.md

- Emit this machine-readable block in `mr-reviewer` final responses after posting the GitLab Review Report.
- Keep the GitLab Review Report comment as the durable review record; this block complements it for parent parsing.
- Preserve field names and top-level order. Run `bash tests/agent-handoff-templates.sh` after editing.
- Make the first fields summary-first for parent orchestration: decision, MR, reviewed SHA, pipeline, local checks, findings, merge action, next action, and report URL.
- If usage limits or tooling failures stop completion before a decision, return prose explaining the blocker; a completed machine block should only claim verified values.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Consumers must tolerate absent blocks and fall back to the Review Report / human prose / Reviewer Lift.

## review-report.md

- Post as a single top-level comment on the MR. Use inline review comments for line-anchored findings, and reference each Must Fix item ID (MF-1, MF-2, ...) so revision commits can cite them.
- **Decision Summary** — First section and first screen. Fill before metadata, Reviewer Lift detail, and evidence detail. Use the same summary-first structure as the reviewer prompts: decision, reviewed SHA, CI status/SHA, findings summary (`MF-N` / `SF-N` / `C-N` counts or IDs), local checks, and Report link placeholder (`this comment; final handoff contains URL when available` until GitLab exposes the comment URL).
- **Summary** — Overall assessment. If requesting changes, state the headline.
- **Decision** — Approve / Request Changes / Reject. Repeat unambiguously.
- **Reviewer Lift (builder handoff)** — Copy every field from the builder's Reviewer Lift before reading the diff. `../../start-build/templates/reviewer-lift-schema.md` owns field names, order, and required semantics; the table in this report is an approved generated copy. Verify each copied value against MR metadata, diff, comments, and CI before deciding. For `Merge authority`, explicit `approval-only` is valid; missing or ambiguous `Merge authority` blocks approval/merge/close actions. Do not default missing authority to approval-only.
- **Must Fix** — Blocking items. Each item: stable ID, path + line/range, problem, and suggested direction if not obvious. Prefix credential/security findings with `[SECURITY]`.
- **Should Fix** — Non-blocking but should be addressed. SF-1, SF-2, ...
- **Consider** — Optional suggestions / preferences / future work. C-1, C-2, ...
- **Safety Checklist** — Pass/fail/N/A for applicable invariants: domain envelope preserved; product/runtime/operator external-system mutations only via approved adapters; observe/enforce or dry-run/production gates intact; protective sequencing intact; coordination primitive (lease/lock) acquired and not force-stolen; immutable baselines and monotonic invariants preserved; exact-decimal numeric type for money/quantity/domain math; pure engines side-effect free.
- **State / Migration / Persistence Checklist** — Typed models, atomic writes, append-only migrations, transactional events, CLI/interop contracts.
- **External-System and Credential Checklist** — No live mutation, adapter-only calls, fake/recorded HTTP tests, redaction, secrets untouched.
- **Tests and Evidence Reviewed** — Builder evidence accepted/rejected; tests you ran; CI status. Note whether `CI pipeline` SHA matches `Reviewed SHA` when GitLab exposes it.
- **Acceptance Criteria Evidence Checked** — For each acceptance criterion from the MR/issue, state accepted evidence or gap.
- **TDD / Behavior-Test Evidence** — Behavior-touching MR: public interface tested? `RED`/`GREEN` trace present or reasonably N/A? Tests avoid implementation coupling? Non-behavior MR: "N/A".
- **Code I Ran** — Exact read-only commands and concise result, or "None". Never paste secrets or run mutating product/runtime/operator commands.
- **Reviewer Focus Sweep** — What the builder flagged in Reviewer Lift > Reviewer Focus, and what you found when you read those areas first. "None flagged" if the builder did not name any.
- **Open Questions Addressed** — One subsection per OQ-N from the MR description. Either answer it, defer to human (and say so), or downgrade to an evidence request. Unanswered OQs cannot sit silently.
- **Praise** — Required. Call out good work / patterns to reinforce.
- **Architectural Observations** — Broader patterns, ADR suggestions, or rejection rationale.
- **Follow-ups for Other Tasks** — Items not blocking this MR. Open separate issues and link them when a `C-N` or other non-blocking finding should survive after merge. Record brief-quality defects here too when the issue brief omitted critical context, acceptance criteria, test strategy, or non-goals; name the missing fields and the avoidable discovery or rework. Use only the documented GitLab/local issue workflow and live label vocabulary.
- **Final Notes** — Short.

## unblock-response.md

- Use when responding to a Stuck Packet. Post as an MR comment. When Builder resumes, remove the project's unblock label if one exists.
- **Summary** — One paragraph: your read and the recommended direction.
- **Direction** — Pointer / correction / pair / escalation. Cite files, tests, docs, or commands.
- **Safety notes** — Any product/runtime/operator external-system / credential / state precautions before continuing.
- **What I did not check** — Honest scope.
- **Confidence** — High / medium / low and why.

## adr.md

See the [shared ADR filling guide](../../templates/filling-guide.md) for ADR template filling instructions.
