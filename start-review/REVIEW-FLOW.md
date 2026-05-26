# Start Review Flow

Detailed workflow for `start-review`. Read before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide or `gitlab-local` for direct `glab` command syntax and flag pitfalls.

## Review modes

1. **Fresh-session reviewer** — fresh agentic session loaded with the MR URL, linked issue, and project rulebook. Triggered by a human, a parent orchestrator after child `mr-builder` final handoff, a separate builder session, or the [Mandatory review gate](../start-build/BUILD-FLOW.md#mandatory-review-gate) (the default invocation when standalone `/start-build` completes implementation). The Mandatory review gate trigger uses a structured handoff: MR URL + pointer to the Reviewer Lift block in the MR description + project rulebook path. In all cases, the reviewer reads the diff fresh, runs its own tests, and makes its own judgment.
2. **Human reviewer** — when the user wants human judgment or project rules require it.

Builder and reviewer may share the same GitLab account/PAT — review independence comes from session/context separation, not GitLab identity. Approval is reviewer-driven and requires explicit authority. Explicit `approval-only` is valid: the reviewer may approve with the reviewed SHA, then stop before merge or auto-merge. Merge immediately or queue auto-merge only when the builder/project-declared `Merge authority` allows it. If `Merge authority` is missing, contradictory, or ambiguous, post the Review Report with no approval, merge, auto-merge, or close action and list the blocker. For multiple MRs, approval and merge/auto-merge happen independently per MR.

## GitLab tooling reference

The command reference intentionally lives in the host project's issue-tracker guide, or in the `gitlab-local` skill when a project has no guide. Use its canonical snippet names for preflight/auth, issue/MR/CI syntax, artifact capture, file-backed comments/descriptions, known `glab` flag pitfalls, and separated SHA-bound action snippets. This flow names commands only where sequencing matters, and keeps SHA-bound approval, merge, auto-merge queueing, and approval confirmation choices visible at decision points.

## MR pickup

When the user supplies MR IDs/URLs/branches, review them if suitable. Otherwise pick one MR or a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md) from the **current GitLab project**:

1. Run `gitlab-local` **Snippet: local-repo-preflight** to confirm `glab` resolves to the cwd repo. If preflight fails, stop and ask.
2. If the current branch has an MR (use `gitlab-local` **Snippet: mr-pickup**), prefer it when the user says "this branch" or the branch is clearly under review.
3. Otherwise list open non-draft MRs with `gitlab-local` **Snippet: mr-pickup**. Narrow with `-l/--label`, `-a/--assignee=@me`, `-r/--reviewer=@me`, `-t/--target-branch` as needed. Prefer MRs labeled with the project's ready-for-review equivalent, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
4. Deprioritize drafts, blocked MRs, MRs labeled with the project's revision/unblock/WIP equivalent, and obviously red-CI MRs unless the user asked for failure triage.
5. Inspect 3-5 candidates with `gitlab-local` **Snippet: mr-pickup** (or enough to validate coupling for multiple). Don't dump raw JSON; summarize MR ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
6. If one MR or one contract-satisfying set is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user to choose.
7. For multiple supplied/requested MRs, prefer the builder's `Reviewer Lift > Decoupling proof` from each MR description and apply the [Decoupling Contract's reviewer consumer guidance](../docs/decoupling-contract.md#reviewer-consumer-guidance). If proof is absent, insufficient, inconsistent, or contradicted by evidence, collect changed paths with `gitlab-local` **Snippet: artifact-capture** (or the GitLab changes API) before declaring the set decoupled.

## Handoff integrity check

Before reading the full diff, validate the builder handoff:

- Reviewer Lift exists and its rows match `start-build/templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema, and the Review Report derives the same rows.
- MR head SHA equals `Reviewed SHA`. If not, read the delta note/revision packet and re-diff the new commits before approval.
- CI pipeline evidence includes URL/ID, status, and commit SHA when available. Treat green CI for an older SHA as stale, not green.
- Local gate is PASS, N/A with rationale, or a clear blocker.
- Open Questions is either `none` or real `OQ-N` IDs. Ignore template placeholders only when obviously not filled, and request cleanup if ambiguous.
- Merge authority is explicit; if it is missing, contradictory, or ambiguous, block approval/merge/close actions and report the blocker. Explicit `approval-only` is valid and means approval may proceed after normal guards, but merge/auto-merge may not.
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
6. Produce one Review Report and one decision per MR. Do not batch multiple MRs into one GitLab comment, approval, request-changes, or reject action.
7. Approval/merge sequence per MR:
   - re-run `gitlab-local` **Snippet: sha-guard** immediately before any approval, merge, or auto-merge action; the decision point must visibly bind the reviewed head: `current_sha="$(glab mr view <id> -F json | jq -r '.sha')"` then compare it to `reviewed_sha`;
   - approve with `gitlab-local` **Snippet: sha-bound-approval** only when approval is authorized;
   - confirm approval with `gitlab-local` **Snippet: approval-confirmation** when approval status must be verified;
   - direct merge with `gitlab-local` **Snippet: sha-bound-merge** only when direct merge is authorized;
   - queue protected auto-merge with `gitlab-local` **Snippet: sha-bound-auto-merge-queue** only when queueing auto-merge is authorized;
   - choose one action at each authorization point; never run a combined approval/merge block or paste multiple action snippets as one executable sequence;
   - after merging one MR, re-check remaining MRs' CI and `detailed_merge_status`; if one becomes conflicted/stale, stop that MR and report the blocker instead of forcing.
8. Remove a review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Then delete the temp ref if no other review uses it: `git update-ref -d refs/tmp/review/mr-<iid>`.

## Procedure

1. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pickup. If multiple, enter **Multiple MR worktree mode** and run the rest independently per MR.
2. Read the linked issue and MR description before the diff using `gitlab-local` **Snippet: issue-pickup** and **Snippet: mr-pickup**. Keep context narrow: start with the MR description, Reviewer Lift, linked issue, changed paths, rulebook, and directly referenced docs/tests; expand only from concrete evidence such as imports/callers, failing tests, safety invariants, or surprising diff behavior.
3. **Lift the builder's `Reviewer Lift` block.** Copy each field from `start-build/templates/reviewer-lift-schema.md` into the matching Review Report fields. If the block is missing or empty (older MRs), record that and re-derive non-authority values yourself; do not infer authority. Missing, contradictory, or ambiguous `Merge authority` blocks approval/merge/close actions until the Review Packet, project rulebook, parent, or human supplies explicit authority.
4. Confirm the MR `sha` from `gitlab-local` **Snippet: mr-pickup** equals the lifted `Reviewed SHA`. If they differ, the builder pushed after marking ready; read the delta note / `Delta since last ready push`, treat the new commits as part of this review, and either re-diff them or request a Revision Packet referencing them before approval.
5. Check labels/status, changed paths, and declared safety-critical surfaces without changing approval eligibility solely due to label absence/mismatch.
6. **Sweep `Reviewer Focus` first** — read those areas hardest before walking the full diff with `gitlab-local` **Snippet: artifact-capture** as needed. Note your findings in the Review Report's `Reviewer Focus Sweep` section even when nothing is wrong.
7. Walk the review categories: scope match, strategy/safety invariants, architecture boundaries, correctness (edges, recovery, exact-decimal math, concurrency, timestamps), tests/evidence, external-API safety (adapters/quirks/redaction), state/DB/migrations (typed models, atomic writes, append-only migrations), observability/ops (metrics, health, runbooks), security/credentials, and engineering quality. For behavior-touching MRs, apply `tdd` test-quality principles when judging evidence.
8. Verify CI status against the lifted `CI pipeline` value with `gitlab-local` **Snippet: ci-decision-snapshot**. When GitLab exposes the pipeline commit SHA, it must equal the reviewed SHA before green CI counts. Flag stale/mismatched CI.
9. Pull and run targeted tests in that MR's worktree when behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution. Do **not** run mutating commands.
10. **Address every `OQ-N` from the MR description in the report's `Open Questions Addressed` section.** For each: answer it, escalate to human, or downgrade to an evidence request. An MR cannot be approved while OQs sit unanswered.
11. Post inline comments for specific lines where useful.
12. Post one top-level **Review Report** comment per MR with `gitlab-local` **Snippet: note-comment-creation** using `templates/review-report.md`. Fill **Reviewer** metadata as `@reviewer — <model-id>` (e.g. `@reviewer — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing.
13. **Re-run `gitlab-local` Snippet: sha-guard immediately before approving.** The decision point must visibly compare `current_sha="$(glab mr view <id> -F json | jq -r '.sha')"` with `reviewed_sha`. If `sha` no longer matches the SHA you reviewed (builder pushed during your review), re-diff the new commits before approving — never approve a SHA you haven't read.
14. Decide per MR by the posted Review Report: approve, request changes, or reject. Approval uses `gitlab-local` **Snippet: sha-bound-approval** and remains visibly SHA-bound. Merge uses `gitlab-local` **Snippet: sha-bound-merge** and auto-merge queueing uses **Snippet: sha-bound-auto-merge-queue** only when `Merge authority` allows that exact action. Request changes keeps the MR open. Reject is non-mutating by default: do not close the MR unless explicit human/project close authority says to close it.

## Review Report expectations

See [templates/filling-guide.md §review-report.md](templates/filling-guide.md#review-reportmd) for the canonical list of report sections and per-section guidance. Every Must Fix names path + line/range + concrete problem + suggested direction if not obvious. Use inline comments for line-anchored findings and reference Must Fix IDs so revision commits can cite them.

## Decisions

- **Approve** — scope matches, no Must Fix remains, all `OQ-N` answered/escalated, tests/evidence adequate, head SHA equals the SHA you reviewed, `Merge authority` is explicit, and CI is green/waived or safely pending (see [BUILD-FLOW.md §Implementation flow](../start-build/BUILD-FLOW.md#implementation-flow) step 9 for the CI-pending auto-merge policy). Re-run `gitlab-local` **Snippet: sha-guard**, then choose the authorized action: `gitlab-local` **Snippet: sha-bound-approval** for approval, **Snippet: approval-confirmation** to verify approval when needed, **Snippet: sha-bound-merge** for direct merge, or **Snippet: sha-bound-auto-merge-queue** for protected auto-merge queueing. If authority is approval-only/human release, stop after approval and report that. If authority is missing, contradictory, or ambiguous, do not approve; report the exact blocker.
- **Request changes** — fixable Must Fix items and the approach is sound. Apply the project's revision label if one exists; keep the MR open.
- **Reject** — premise/architecture/scope is wrong, or a safety boundary is weakened beyond what the user/project accepts. Post the Review Report with the reject decision, explain why and what would need to change before a new or continued MR can proceed, then stop and escalate to the parent/human. Leave the MR open by default; closing an MR requires explicit human/project close authority. Reject requires human follow-up; don't auto-spawn a revision.

## After review

- **Request changes:** Build agent pushes commits and replies to threads; reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution.
- **Approve:** Reviewer has approved and, when merge authority allowed it, merged or queued auto-merge. Each approved MR has its own reviewed SHA and merge/auto-merge/approval-only result. If a durable summary is required, ensure the MR links are recorded there.
- **Reject:** Review Report is posted and the reviewer stops/escalates to the parent/human. Do not close the MR unless explicit human/project close authority says to close it.
- **Stuck Packet:** post `templates/unblock-response.md` as an MR comment, give short direction, and remove the project's unblock label when one exists and work resumes.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Reviewer template filling guide](templates/filling-guide.md)
- [Shared ADR filling guide](../templates/filling-guide.md)

Safety-critical filling rules remain in this flow:

- Copy every field from the canonical Reviewer Lift schema before reading the full diff, and verify MR head SHA equals `Reviewed SHA` immediately before any decision.
- Treat CI evidence as valid only when the pipeline commit SHA (when GitLab exposes it) matches the reviewed SHA; red or stale CI blocks approval unless explicitly waived.
- Never paste secrets, credentials, auth headers, sensitive payloads, or unredacted logs into Review Reports, inline comments, templates, or CI output.
- Address every stable `OQ-N` from the MR description; unresolved open questions require escalation or request-changes.
- Use stable review item IDs (`MF-N`, `SF-N`, `C-N`) for Must Fix, Should Fix, and Consider items so revision commits and responses can cite them.
