# Start Review Flow

Detailed workflow for `start-review`. Read before selecting MR(s), commenting, approving, merging, requesting changes, rejecting, or reporting a blocked review. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide or `gitlab-local` for direct `glab` command syntax and flag pitfalls.

## Review modes

1. **Fresh-session reviewer** — fresh agentic session loaded with the MR URL, linked issue, and project rulebook. Triggered by a human, a parent orchestrator after child `mr-builder` final handoff, a separate builder session, or the [Mandatory review gate](../start-build/BUILD-FLOW.md#mandatory-review-gate) (the default invocation when standalone `/start-build` completes implementation). The Mandatory review gate trigger uses a structured handoff: MR URL + pointer to the Reviewer Lift block in the MR description + project rulebook path. In all cases, the reviewer reads the diff fresh, runs its own tests, and makes its own judgment.
2. **Human reviewer** — when the user wants human judgment or project rules require it.

Builder and reviewer may share the same GitLab account/PAT — review independence comes from session/context separation, not GitLab identity. The review judgment is the `Review verdict` (`pass / request-changes / reject / blocked`). GitLab side effects are separate: `Approval action`, `Finish action`, `Action blocker`, and `Next action`. Approval is reviewer-driven and requires explicit authority plus a verifiable `Merge authority source`. Explicit `approval-only` is valid: the reviewer may approve with the reviewed SHA, then stop before merge or auto-merge when the source verifies it. Merge immediately or queue auto-merge only when the quoted `Merge authority` and verified source allow it. If `Merge authority` or `Merge authority source` is missing, contradictory, or ambiguous, post the Review Report with `Review verdict: blocked`, `Approval action: blocked`, `Finish action: none`, and `Action blocker: missing-authority`; take no approval, merge, auto-merge, or close action. For multiple MRs, review verdicts and actions happen independently per MR.

## Authority source precedence

`Merge authority` in the Review Packet is a builder-quoted claim, not a grant. The reviewer verifies `Merge authority source` before any approval, merge, or auto-merge action. Accepted sources include parent task prompt, human MR comment URL, rulebook path+section, or project default source. Explicit human or parent instruction beats rulebook/project default. When sources conflict, choose the most restrictive/no action path and report `Review verdict: blocked` with `Action blocker: missing-authority` unless a human/parent resolves it. `reviewer may merge`, `queue auto-merge`, and `project default: ...` without a verifiable source are blocked as missing authority.

## CI and Open Question decision tables

Use these tables as the canonical approval/finish policy for CI and reviewer Open Questions. Other reviewer-facing docs should point here instead of restating the matrix.

### CI decision table

| CI state | Approval / finish decision | Required evidence / conditions | Action fields |
|---|---|---|---|
| exact-SHA success | Approval and authorized finish may proceed after normal review, SHA, and authority guards. | Decision-grade pipeline status is success/green, and pipeline SHA equals `Reviewed SHA` when GitLab exposes SHA. | `CI status / SHA: green`; `Action blocker: none`. |
| exact-SHA pending under protected auto-merge | Approval and queue-auto-merge are eligible only for protected auto-merge; direct merge is not eligible while CI is pending. | All conditions hold: local gate PASS; pending pipeline is tied to reviewed SHA when GitLab exposes SHA; protected merge checks enforce green CI before merge; `queue auto-merge` authority and verifiable source allow queueing. | `CI status / SHA: pending-auto-merge`; `Finish action: auto-merge queued` when queueing succeeds, otherwise `Next action: wait-ci`. |
| red/failed/canceled/skipped | No approval, merge, or queue action. | Pipeline for reviewed SHA is failed, red, canceled, skipped, or has required-job failure. If logs expose a fixable builder defect, record it as `MF-N`; approval still stays blocked until CI is fixed or human-waived. | `Review verdict: blocked` or `request-changes` with no approval; `Action blocker: stale-or-missing-ci`. |
| missing | No approval, merge, or queue action unless the human-waived row applies. | No decision-grade MR/branch pipeline is available for reviewed SHA, and project policy does not explicitly make CI N/A. | `Review verdict: blocked`; `Action blocker: stale-or-missing-ci`; `Next action: wait-ci` or `fix-blocker`. |
| stale | No approval, merge, or queue action unless the human-waived row applies. | Latest green/pending pipeline SHA differs from `Reviewed SHA`, or MR head changed after the reviewed pipeline. | `Review verdict: blocked`; `Action blocker: stale-or-missing-ci` or `changed-head-sha` when head changed. |
| human-waived | Approval and authorized finish may proceed only if the waiver explicitly covers the CI blocker. | Authorized human waiver source/comment is present in the MR, or the parent task quotes that human waiver source/comment; it names the CI state being waived and is recorded in the Review Report. Reviewer cannot self-waive CI. | `CI status / SHA: waived`; `Action blocker: none` for CI, while other guards still apply. |

### Open Question decision table

| OQ state | Review outcome | Required reviewer handling |
|---|---|---|
| answered from evidence | ok; pass allowed when every other guard passes. | Answer the `OQ-N` in `Open Questions Addressed`, cite evidence, and remove it from blockers. |
| builder evidence gap | request-changes. | Record an `MF-N` evidence request or targeted Must Fix, and require builder revision before approval. |
| human/product/security decision | blocked/no approval. | Use `Action blocker: human-decision-needed`, `Next action: human-escalation`, and do not approve until the decision source is recorded. |
| non-blocking | `C-N` / follow-up with rationale; pass may still proceed when other guards pass. | Downgrade explicitly in `Open Questions Addressed`, explain why it is non-blocking, and link/create a follow-up when it must survive merge. |

## GitLab tooling reference

The command reference intentionally lives in the host project's issue-tracker guide, or in the `gitlab-local` skill when a project has no guide. Use its canonical snippet names for preflight/auth, issue/MR/CI syntax, artifact capture, file-backed comments/descriptions, known `glab` flag pitfalls, and separated SHA-bound action snippets. This flow names commands only where sequencing matters, and keeps SHA-bound approval, merge, auto-merge queueing, and approval confirmation choices visible at action points.

## MR pickup

When the user supplies MR IDs/URLs/branches, review them if suitable. Otherwise pick one MR or a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md) from the **current GitLab project**:

1. Run `gitlab-local` **Snippet: local-repo-preflight** to confirm `glab` resolves to the cwd repo. If preflight fails, post/report `Review verdict: blocked` with `Action blocker: preflight-failure` when an MR context exists; otherwise stop and ask.
2. If the current branch has an MR (use `gitlab-local` **Snippet: mr-pickup**), prefer it when the user says "this branch" or the branch is clearly under review.
3. Otherwise list open non-draft MRs with `gitlab-local` **Snippet: mr-pickup**. Narrow with `-l/--label`, `-a/--assignee=@me`, `-r/--reviewer=@me`, `-t/--target-branch` as needed. Prefer MRs labeled with the project's ready-for-review equivalent, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
4. Deprioritize drafts, blocked MRs, MRs labeled with the project's revision/unblock/WIP equivalent, and obviously red-CI MRs unless the user asked for failure triage.
5. Inspect 3-5 candidates with `gitlab-local` **Snippet: mr-pickup** (or enough to validate coupling for multiple). Don't dump raw JSON; summarize MR ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
6. If one MR or one contract-satisfying set is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user to choose.
7. For multiple supplied/requested MRs, prefer the builder's `Reviewer Lift > Decoupling proof` from each MR description and apply the [Decoupling Contract's reviewer consumer guidance](../docs/decoupling-contract.md#reviewer-consumer-guidance). If proof is absent, insufficient, inconsistent, or contradicted by evidence, collect changed paths with `gitlab-local` **Snippet: artifact-capture** (or the GitLab changes API) before declaring the set decoupled.

## Handoff integrity check

Before reading the full diff, validate the builder handoff:

- Reviewer Lift exists and its rows match `start-build/templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema, and the Review Report derives the same rows.
- MR head SHA equals `Reviewed SHA`. If not, read the delta note/revision packet and re-diff the new commits before approval. If you cannot safely review the new head, report `Review verdict: blocked` with `Action blocker: changed-head-sha`.
- CI pipeline evidence includes URL/ID, status, and commit SHA when available. Classify it with the [CI decision table](#ci-decision-table) before any approval or finish action.
- Local gate is PASS, N/A with rationale, or a clear blocker.
- Open Questions is either `none` or real `OQ-N` IDs. Ignore template placeholders only when obviously not filled, and classify real questions with the [Open Question decision table](#open-question-decision-table).
- Merge authority is explicit and treated as a quoted builder claim, not a grant. `Merge authority source` is mandatory and verifiable; if authority or source is missing, contradictory, unverifiable, or ambiguous, block approval/merge/close actions and report `Action blocker: missing-authority`. Explicit `approval-only` is valid when its source verifies it and means approval may proceed after normal guards, but merge/auto-merge may not.
- Post-ready pushes include an old SHA → new SHA delta comment; substantive deltas should have a Revision Packet.

## Multiple MR worktree mode

Use when the user supplies multiple MRs, asks for multiple reviews, or asks to review the next N ready MRs.

1. Resolve candidates first. Collect at least IID, title, source branch, target branch, head SHA, author, labels, CI state, linked issue, and changed paths.
2. **Read the builder's `Reviewer Lift > Decoupling proof` from each MR description first.** Apply the [Decoupling Contract's reviewer consumer guidance](../docs/decoupling-contract.md#reviewer-consumer-guidance): accept mutually consistent proofs that align with sampled paths and metadata; re-derive when proofs are missing, insufficient, inconsistent, or contradicted by evidence.
3. If coupling is unclear after the contract check, review serially in the safest order or ask the user to choose. Never parallelize coupled work to save time, and never batch-approve coupled MRs.
4. Use the original checkout as a coordinator for GitLab queries only. Create one review worktree per MR when local checkout/tests are needed. Do not use shared `FETCH_HEAD` in parallel review mode; fetch each MR into its own temp ref:
   - `git fetch origin +refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>`
   - `git worktree add --detach <path> refs/tmp/review/mr-<iid>`
   - `git -C <path> rev-parse HEAD` must equal MR metadata `sha`; if not, refresh metadata and stop if still mismatched.
5. If a parent/harness has already provided parallel reviewer sessions and worktrees, keep one reviewer session per MR/worktree. If you are running inside a reviewer child session, review only the assigned MR/worktree and do not launch sibling reviewers. Review independence requires separate LLM/session context plus separate checkout for local execution.
6. Produce one Review Report, one `Review verdict`, and one reviewed SHA per MR. Do not batch multiple MRs into one GitLab comment, approval, request-changes, reject, or blocked action.
7. Approval/merge sequence per MR:
   - re-run `gitlab-local` **Snippet: sha-guard** immediately before any approval, merge, or auto-merge action; the decision point must visibly bind the reviewed head: `current_sha="$(glab mr view <id> -F json | jq -r '.sha')"` then compare it to `reviewed_sha`;
   - approve with `gitlab-local` **Snippet: sha-bound-approval** only when approval is authorized;
   - confirm approval with `gitlab-local` **Snippet: approval-confirmation** when approval status must be verified;
   - before direct merge, re-run a fresh SHA guard immediately before direct merge, then use `gitlab-local` **Snippet: sha-bound-merge** only when direct merge is authorized;
   - before queueing auto-merge, re-run a fresh SHA guard immediately before the auto-merge queue action, then use `gitlab-local` **Snippet: sha-bound-auto-merge-queue** only when queueing auto-merge is authorized;
   - choose one action at each authorization point; never run a combined approval/merge block or paste multiple action snippets as one executable sequence;
   - if SHA-bound approval/merge flags are unavailable or unsupported, report `Review verdict: blocked` with `Action blocker: sha-bound-action-unsupported` rather than taking an unpinned action;
   - after merging one MR, re-check remaining MRs' CI and `detailed_merge_status`; if one becomes conflicted/stale, stop that MR and report the blocker instead of forcing.
8. Remove a review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Then delete the temp ref if no other review uses it: `git update-ref -d refs/tmp/review/mr-<iid>`.

## Single MR checkout mode

Use this mode when reviewing one MR and local checkout/tests are needed. Local evidence is valid only from a checkout proven to be at the MR SHA under review; review checkout setup must never move by an arbitrary branch pull.

Allowed current-checkout path:

1. Re-read decision-grade MR metadata and establish `reviewed_sha` from the lifted `Reviewed SHA` plus the current MR metadata `sha`. If those values differ and the delta cannot be reviewed safely, report `Action blocker: changed-head-sha` before local execution.
2. `git status --porcelain` in the current checkout must be empty/clean. If not clean, do not run local checks there.
3. `git rev-parse HEAD` must equal `reviewed_sha` or, when re-deriving for an older MR without a lifted value, the current MR SHA from metadata. Record the checkout path and SHA before running checks.

Fallback exact-SHA worktree path:

1. Do not run `git pull` during review checkout setup; arbitrary `git pull` can test a branch tip or merge result that is not the reviewed MR SHA.
2. Fetch the MR head into a temp ref instead of shared `FETCH_HEAD`: `git fetch origin +refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>`.
3. Create a detached review worktree: `git worktree add --detach <path> refs/tmp/review/mr-<iid>`.
4. Verify `git -C <path> rev-parse HEAD` equals the current MR metadata `sha`; if it does not, refresh MR metadata once and stop with `Action blocker: changed-head-sha` if still mismatched.
5. Run targeted tests/checks only from the verified checkout. The Review Report `Code I Ran` / evidence must record checkout path and SHA used for local checks.
6. Remove a temporary review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty; then delete the temp ref if no other review uses it.

## Procedure

1. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pickup. If multiple, enter **Multiple MR worktree mode** and run the rest independently per MR.
2. Read the linked issue and MR description before the diff using `gitlab-local` **Snippet: issue-pickup** and **Snippet: mr-pickup**. Keep context narrow: start with the MR description, Reviewer Lift, linked issue, changed paths, rulebook, and directly referenced docs/tests; expand only from concrete evidence such as imports/callers, failing tests, safety invariants, or surprising diff behavior.
3. **Lift the builder's `Reviewer Lift` block.** Copy each field from `start-build/templates/reviewer-lift-schema.md` into the matching Review Report fields. If the block is missing or empty (older MRs), record that and re-derive non-authority values yourself; do not infer authority. Missing, contradictory, or ambiguous `Merge authority` or `Merge authority source` blocks approval/merge/close actions until the Review Packet, parent task prompt, human MR comment URL, rulebook path+section, or project default source supplies explicit authority; if no authority can be obtained during review, use `Review verdict: blocked` and `Action blocker: missing-authority`. Apply authority source precedence from this flow: explicit human or parent instruction beats rulebook/project default, builder claims do not grant authority, and conflicts choose the most restrictive/no action path.
4. Confirm the MR `sha` from `gitlab-local` **Snippet: mr-pickup** equals the lifted `Reviewed SHA`. If they differ, the builder pushed after marking ready; read the delta note / `Delta since last ready push`, treat the new commits as part of this review, and either re-diff them or request a Revision Packet referencing them before approval. If safe re-review is not possible, report `Action blocker: changed-head-sha`.
5. Check labels/status, changed paths, and declared safety-critical surfaces without changing approval eligibility solely due to label absence/mismatch.
6. **Sweep `Reviewer Focus` first** — read those areas hardest before walking the full diff with `gitlab-local` **Snippet: artifact-capture** as needed. Note your findings in the Review Report's `Reviewer Focus Sweep` section even when nothing is wrong.
7. Walk the review categories: scope match, strategy/safety invariants, architecture boundaries, correctness (edges, recovery, exact-decimal math, concurrency, timestamps), tests/evidence, external-API safety (adapters/quirks/redaction), state/DB/migrations (typed models, atomic writes, append-only migrations), observability/ops (metrics, health, runbooks), security/credentials, and the bounded structural maintainability sweep. For behavior-touching MRs, apply `tdd` test-quality principles when judging evidence.
8. Verify CI status against the lifted `CI pipeline` value with `gitlab-local` **Snippet: ci-decision-snapshot**, then classify it with the [CI decision table](#ci-decision-table).
9. When local execution is needed because behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution, enter **Single MR checkout mode** first for one MR (or the existing multiple-MR worktree path for multiple MRs), then run targeted tests only from the verified exact-SHA checkout. Do **not** run mutating commands.
10. **Address every `OQ-N` from the MR description in the report's `Open Questions Addressed` section.** Classify each question with the [Open Question decision table](#open-question-decision-table) before choosing the review verdict or action fields.
11. Post inline comments for specific lines where useful.
12. **Draft the Review Report before final guards.** Normative report/action order: draft Review Report -> final MR/CI/authority snapshot -> convert to blocked if any guard fails -> post Review Report -> SHA guard before approval -> authorized action -> optional action-result note/final handoff. Fill **Reviewer** metadata as `@reviewer — <model-id>` (e.g. `@reviewer — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing. In the draft, action fields describe the intended action when approval/merge/auto-merge will happen after posting; they must not claim completed GitLab side effects before those effects are verified.
13. **Take the final MR/CI/authority snapshot before posting.** Re-read MR metadata, current head SHA, pipeline SHA/status, `detailed_merge_status`, explicit `Merge authority`, and verifiable `Merge authority source`. If a final guard fails, convert the drafted report to `Review verdict: blocked`, set the appropriate `Action blocker`, set approval/finish actions to blocked or none, and only then post the report. Do not post a pass report whose own final snapshot is already stale, red, missing authority, or otherwise blocked.
14. Post one top-level **Review Report** comment per MR with `gitlab-local` **Snippet: note-comment-creation** using `templates/review-report.md`. Fill `Review verdict`, `Approval action`, `Finish action`, `Action blocker`, and `Next action` before posting, using intended-action wording for post-report actions and completed-action wording only for side effects already verified.
15. **Re-run `gitlab-local` Snippet: sha-guard immediately before approving.** The action point must visibly compare `current_sha="$(glab mr view <id> -F json | jq -r '.sha')"` with `reviewed_sha`. If the head SHA changes after the report is posted but before action, skip approval, merge, and auto-merge; the optional action-result note or final handoff reports the stale SHA, current SHA, reviewed SHA, `Action blocker: changed-head-sha`, and `Next action: rerun-review`. Never approve a SHA you haven't read.
16. Apply the posted Review Report outcome. `pass` may proceed to a separate, authorized approval action after the post-report SHA guard. `request-changes` keeps the MR open for builder revision. `reject` is non-mutating by default: do not close the MR unless explicit human/project close authority says to close it. `blocked` takes no approval, merge, auto-merge, or close action; route by `Action blocker` and `Next action`. Permission failures during approval/merge map to `Action blocker: permission-failure`; record the failed action in the final handoff and, when useful for durable MR history, an action-result note.
17. **Guard before each finish action.** Before direct merge, re-run a fresh SHA guard immediately before direct merge, then use `gitlab-local` **Snippet: sha-bound-merge** only when direct merge is authorized. Before queueing auto-merge, re-run a fresh SHA guard immediately before the auto-merge queue action, then use `gitlab-local` **Snippet: sha-bound-auto-merge-queue** only when queueing is authorized. If the head changed, skip that finish action and report `changed-head-sha` in the action-result note/final handoff rather than acting on the stale report.
18. **Final reviewer handoff.** After posting the Review Report and after any authorized approval, merge, or auto-merge action attempt, the final response MUST include the machine-readable block from `templates/reviewer-final-handoff.md` when that template is available. Fill it with the same verdict/action vocabulary as the Review Report: `review_verdict` (`pass / request-changes / reject / blocked`), `reviewed_sha`, pipeline status/SHA, local checks, `MF-N` / `SF-N` / `C-N` finding IDs, Open Question handling, `merge_authority`, `merge_authority_source`, `approval_action`, `finish_action`, `action_blocker`, `next_action`, and `report_url` or `N/A`. Keep the GitLab Review Report comment as the durable review record; the final handoff is a parseable session artifact for parent orchestrators and records completed action results after post-report action attempts. If the template is unavailable, say so and still return those verified fields in prose/YAML; do not invent MR, CI, approval, action, blocker, or report-link state.

## Structural maintainability sweep

Run this as a diff-first, blast-radius-bounded pass. Start with the MR diff, Reviewer Lift, linked issue, changed paths, and rulebook. Expand only to surrounding callers, tests, docs, or existing helpers when concrete diff evidence shows risk. This is not a default whole-repo architecture audit.

Check for evidence-backed implementation-quality regressions:

- **Code-judo simplification:** an obvious reframing that preserves behavior while deleting branches, modes, helper layers, wrappers, or concepts the reader must hold.
- **Spaghetti or special-case branching:** ad-hoc conditionals, flags, nullable modes, or edge-case branches bolted into already-busy flows instead of a focused helper, model, policy, state machine, or module.
- **Unjustified wrappers or abstractions:** pass-through helpers, identity wrappers, magical generic handling, or indirection that does not buy clarity.
- **Wrong-layer logic / duplicate helpers:** feature logic leaking into shared paths, implementation details leaking through APIs, bespoke helpers where a canonical utility already owns the concept.
- **Type-boundary issues:** `any`, `unknown`, cast-heavy paths, unnecessary optionality, or silent fallbacks that hide a real invariant instead of making the contract explicit.
- **Avoidable orchestration complexity:** independent work serialized for no clear reason, or related updates made non-atomic when a cleaner structure is obvious. Do not block on micro-optimizations.
- **1k-line threshold:** if the MR pushes a file from `<1000` lines to `>1000` lines, treat it as a strong code-quality smell and presumptive Must Fix unless the MR gives a compelling decomposition rationale and the resulting file remains clearly organized.

Decision rule: block as `MF-N` when the diff introduces or preserves material structural complexity and a bounded remedy is visible inside the MR's blast radius, especially for unjustified `<1000` -> `>1000` file growth. Use `C-N` for style-only preferences, speculative broader redesigns, cleanup outside the changed paths, or improvements with no clear local remedy. Do not request changes for taste, naming, or formatting when project checks already cover them.

## Review Report expectations

See [templates/filling-guide.md §review-report.md](templates/filling-guide.md#review-reportmd) for the canonical list of report sections and per-section guidance. Every Must Fix names path + line/range + concrete problem + suggested direction if not obvious. Use inline comments for line-anchored findings and reference Must Fix IDs so revision commits can cite them.

## Decisions

- **Pass** — scope matches, no Must Fix remains (including no blocker-level structural maintainability regression), every `OQ-N` is classified as pass-eligible by the [Open Question decision table](#open-question-decision-table), tests/evidence are adequate, head SHA equals the SHA you reviewed, `Merge authority` is explicit, `Merge authority source` is verifiable, and CI is pass-eligible by the [CI decision table](#ci-decision-table). Re-run `gitlab-local` **Snippet: sha-guard**, then choose the authorized action: `gitlab-local` **Snippet: sha-bound-approval** for approval, **Snippet: approval-confirmation** to verify approval when needed, **Snippet: sha-bound-merge** for direct merge, or **Snippet: sha-bound-auto-merge-queue** for protected auto-merge queueing. If authority is approval-only/human release, stop after approval and report that as the Finish action. `pass` does not imply approval happened; `Approval action` says whether it did.
- **Request changes** — fixable Must Fix items and the approach is sound. Apply the project's revision label if one exists; keep the MR open.
- **Reject** — premise/architecture/scope is wrong, or a safety boundary is weakened beyond what the user/project accepts. Post the Review Report with the reject verdict, explain why and what would need to change before a new or continued MR can proceed, then stop and escalate to the parent/human. Leave the MR open by default; closing an MR requires explicit human/project close authority. Reject requires human follow-up; don't auto-spawn a revision.
- **Blocked** — guard/tool/authority state prevents a safe approval or finish without judging the code as fixable or invalid. Use `Approval action: blocked` or `not-approved`, `Finish action: none` or `blocked`, and one `Action blocker`: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, or `other`. Parent orchestrators route blocked outcomes to authority/CI/tooling/human-decision handling, not to builder code revision unless the blocker itself names builder work.

## After review

- **Request changes:** Build agent pushes commits and replies to threads; reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution.
- **Pass:** Reviewer has posted a passing review judgment and separately recorded Approval action and Finish action. Each passing MR has its own reviewed SHA and approval/merge/auto-merge/approval-only result. If a durable summary is required, ensure the MR links are recorded there.
- **Reject:** Review Report is posted and the reviewer stops/escalates to the parent/human. Do not close the MR unless explicit human/project close authority says to close it.
- **Blocked:** Review Report is posted, no approval/merge/close action is taken, and the parent/human routes by `Action blocker` and `Next action`.
- **Stuck Packet:** post `templates/unblock-response.md` as an MR comment, give short direction, and remove the project's unblock label when one exists and work resumes.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Reviewer template filling guide](templates/filling-guide.md)
- [Shared ADR filling guide](../templates/filling-guide.md)

Safety-critical filling rules remain in this flow:

- Copy every field from the canonical Reviewer Lift schema before reading the full diff, and verify MR head SHA equals `Reviewed SHA` immediately before any decision.
- Classify CI evidence with the [CI decision table](#ci-decision-table); it owns exact-SHA, pending, red, missing, stale, and waived handling.
- Never paste secrets, credentials, auth headers, sensitive payloads, or unredacted logs into Review Reports, inline comments, templates, or CI output.
- Classify every stable `OQ-N` from the MR description with the [Open Question decision table](#open-question-decision-table); it owns evidence, builder-gap, human-decision, and non-blocking handling.
- Use stable review item IDs (`MF-N`, `SF-N`, `C-N`) for Must Fix, Should Fix, and Consider items so revision commits and responses can cite them.
- When a `C-N` or other non-blocking finding should survive after merge, create or link a follow-up issue via the documented GitLab/local issue workflow and current live labels only; keep the current MR scope unchanged.
- When the issue brief omitted critical context, acceptance criteria, test strategy, or non-goals, record a brief-quality defect in the Review Report follow-ups section, naming the missing fields and any avoidable discovery or rework it caused.
