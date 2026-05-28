# Template Filling Guide — Start Review

This guide holds instructional prose for reviewer templates. Read once per session; the templates themselves are bare skeletons.

## reviewer-final-handoff.md

- Emit this machine-readable block in `mr-reviewer` final responses after posting the GitLab Review Report and after any authorized approval/finish action attempt.
- Keep the GitLab Review Report comment as the durable review record; this block complements it as a parseable artifact for parent parsing.
- Preserve field names and top-level order. Run `bash tests/agent-handoff-templates.sh` after editing.
- Make the first fields summary-first for parent orchestration: review verdict, MR, reviewed SHA, pipeline, local checks, findings, merge authority, merge authority source, approval action, finish action, action blocker, next action, and report URL.
- `review_verdict` is `pass / request-changes / reject / blocked`. `pass` is a review judgment only; it never means "looks good but no approval was taken". `approval_action`, `finish_action`, and `action_blocker` say what GitLab side effects happened or why none happened.
- Use `blocked` when guard, authority, tooling, permission, or human-decision state prevents safe approval/finish: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, or `other`.
- If usage limits or tooling failures stop completion before a review verdict, return prose explaining the blocker; a completed machine block should only claim verified values.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Consumers must tolerate absent blocks and fall back to the Review Report / human prose / Reviewer Lift.

## review-report.md

- Post as a single top-level comment on the MR. Use inline review comments for line-anchored findings, and reference each Must Fix item ID (MF-1, MF-2, ...) so revision commits can cite them.
- **Decision Summary** — First section and first screen. Fill before metadata, Reviewer Lift detail, and evidence detail. Use the same summary-first structure as the reviewer prompts: review verdict (`pass / request-changes / reject / blocked`), reviewed SHA, CI status/SHA, findings summary (`MF-N` / `SF-N` / `C-N` counts or IDs), local checks, Approval action, Finish action, Action blocker, Merge authority, Merge authority source, Next action, and Report link placeholder (`this comment; final handoff contains URL when available` until GitLab exposes the comment URL).
- **Summary** — Overall assessment. If requesting changes, state the headline. If blocked, name the guard/tool/authority blocker and say whether builder revision is needed.
- **Decision** — Repeat the `Review verdict` and the separate action fields. `pass` means the review judgment passed; it does not imply GitLab approval, merge, or auto-merge. `blocked` is for non-code-review blockers that prevent safe approval/finish.
- **Reviewer Lift (builder handoff)** — Copy every field from the builder's Reviewer Lift before reading the diff. `../../start-build/templates/reviewer-lift-schema.md` owns field names, order, and required semantics; the table in this report is an approved generated copy. Verify each copied value against MR metadata, diff, comments, and CI before deciding. Treat `Merge authority` as a builder-quoted claim, not a grant. `Merge authority source` must be verifiable; accepted sources include parent task prompt, human MR comment URL, rulebook path+section, or project default source. Authority source precedence: explicit human or parent instruction beats rulebook/project default; conflicts choose the most restrictive/no action path. For `Merge authority`, explicit `approval-only` is valid when its source verifies it; missing or ambiguous `Merge authority` or source blocks approval/merge/close actions. `reviewer may merge`, `queue auto-merge`, and `project default: ...` without a verifiable source are blocked. Do not default missing authority to approval-only; record `Action blocker: missing-authority`.
- **Merge authority / Merge authority source** — Preserve both the verified value and source in the Review Report and final handoff. Missing, unverifiable, or conflicting source information maps to `Action blocker: missing-authority`.
- **Approval action** — Record only GitLab approval side effects: approved, not-approved, blocked, or N/A. Do not use a passing review verdict as a substitute for approval evidence.
- **Finish action** — Record only GitLab finish side effects: merged, auto-merge queued, approval-only stop, human-release stop, none, blocked, or N/A.
- **Action blocker** — Use `none` or a stable token: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, or `other`.
- **Next action** — Tell the parent orchestrator how to route: finish-by-authorized-actor, revise, human-escalation, wait-ci, rerun-review, or fix-blocker.
- **Must Fix** — Blocking items. Each item: stable ID, path + line/range, problem, and suggested direction if not obvious. Prefix credential/security findings with `[SECURITY]`.
- **Should Fix** — Non-blocking but should be addressed. SF-1, SF-2, ...
- **Consider** — Optional suggestions / preferences / future work. C-1, C-2, ...
- **Safety Checklist** — Pass/fail/N/A for applicable invariants: domain envelope preserved; product/runtime/operator external-system mutations only via approved adapters; observe/enforce or dry-run/production gates intact; protective sequencing intact; coordination primitive (lease/lock) acquired and not force-stolen; immutable baselines and monotonic invariants preserved; exact-decimal numeric type for money/quantity/domain math; pure engines side-effect free.
- **State / Migration / Persistence Checklist** — Typed models, atomic writes, append-only migrations, transactional events, CLI/interop contracts.
- **External-System and Credential Checklist** — No live mutation, adapter-only calls, fake/recorded HTTP tests, redaction, secrets untouched.
- **Tests and Evidence Reviewed** — Builder evidence accepted/rejected; tests you ran; CI status. Classify CI with `../REVIEW-FLOW.md` [CI and Open Question decision tables](../REVIEW-FLOW.md#ci-and-open-question-decision-tables), then note how `Merge authority source` was verified or why it blocked.
- **Acceptance Criteria Evidence Checked** — For each acceptance criterion from the MR/issue, state accepted evidence or gap.
- **TDD / Behavior-Test Evidence** — Behavior-touching MR: public interface tested? `RED`/`GREEN` trace present or reasonably N/A? Tests avoid implementation coupling? Non-behavior MR: "N/A".
- **Structural Maintainability Sweep** — Summarize the bounded diff-first pass from `REVIEW-FLOW.md`: code-judo simplification, spaghetti/special-case branching, wrappers/abstractions, wrong-layer or duplicate helpers, type-boundary issues, orchestration complexity, and the `<1000` -> `>1000` file threshold. Record blocker-level regressions as `MF-N`; use `C-N` only for non-blocking or broader follow-up quality work; do not block on style-only preferences.
- **Code I Ran** — Exact read-only commands and concise result, or "None". Never paste secrets or run mutating product/runtime/operator commands.
- **Reviewer Focus Sweep** — What the builder flagged in Reviewer Lift > Reviewer Focus, and what you found when you read those areas first. "None flagged" if the builder did not name any.
- **Open Questions Addressed** — One subsection per OQ-N from the MR description. Classify each OQ with `../REVIEW-FLOW.md` [CI and Open Question decision tables](../REVIEW-FLOW.md#ci-and-open-question-decision-tables) and record the outcome.
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
