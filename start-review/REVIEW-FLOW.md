# Start Review Flow

Detailed workflow for `start-review`. Read before selecting MR(s), commenting, approving, merging, requesting changes, or rejecting. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide or `local-gitlab` for direct `glab` command syntax and flag pitfalls.

## Review modes

1. **Fresh-session reviewer** — fresh agentic session loaded with the MR URL, linked issue, and project rulebook. Triggered by a human, a separate builder session, or the [Mandatory review gate](../start-build/BUILD-FLOW.md#mandatory-review-gate) (the default invocation when `start-build` completes implementation). The Mandatory review gate trigger uses a structured handoff: MR URL + pointer to the Reviewer Lift block in the MR description + project rulebook path. In all cases, the reviewer reads the diff fresh, runs its own tests, and makes its own judgment.
2. **Human reviewer** — when the user wants human judgment or project rules require it.

Builder and reviewer may share the same GitLab account/PAT — review independence comes from session/context separation, not GitLab identity. Approval is reviewer-driven. If the reviewer approves, approve in GitLab with the reviewed SHA. Merge immediately or queue auto-merge only when the builder/project-declared `Merge authority` allows it; otherwise stop after approval and report the reviewed SHA. For multiple MRs, approval and merge/auto-merge happen independently per MR.

## GitLab tooling reference

The command reference intentionally lives in the host project's issue-tracker guide, or in the `local-gitlab` skill when a project has no guide. Use it for preflight/auth, issue/MR/CI syntax, worktree snippets, file-backed comments/descriptions, and known `glab` flag pitfalls. This flow names commands only where sequencing matters.

## MR pickup

When the user supplies MR IDs/URLs/branches, review them if suitable. Otherwise pick one MR or a decoupled set from the **current GitLab project**:

1. Run the direct preflight from `local-gitlab` to confirm `glab` resolves to the cwd repo. If preflight fails, stop and ask.
2. If the current branch has an MR (`glab mr view`), prefer it when the user says "this branch" or the branch is clearly under review.
3. Otherwise list open non-draft MRs (`glab mr list --not-draft -F json --per-page 50`). Narrow with `-l/--label`, `-a/--assignee=@me`, `-r/--reviewer=@me`, `-t/--target-branch` as needed. Prefer MRs labeled ready-for-review, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
4. Deprioritize drafts, blocked MRs, MRs labeled needs-revision/needs-unblock/WIP, and obviously red-CI MRs unless the user asked for failure triage.
5. Inspect 3-5 candidates with `glab mr view <id> --comments` (or enough to validate coupling for multiple). Don't dump raw JSON; summarize MR ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
6. If one MR or one decoupled set is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user to choose.
7. For multiple supplied/requested MRs, prefer the builder's `Reviewer Lift > Decoupling proof` from each MR description as input. If absent or insufficient, collect changed paths with `glab mr diff <id> --raw --color=never | git apply --numstat` (or the GitLab changes API) before declaring the set decoupled.

## Handoff integrity check

Before reading the full diff, validate the builder handoff:

- Reviewer Lift exists with all required rows (see `start-build/templates/review-packet.md` for the canonical field list). Full and compact packets use the same rows.
- MR head SHA equals `Reviewed SHA`. If not, read the delta note/revision packet and re-diff the new commits before approval.
- CI pipeline evidence includes URL/ID, status, and commit SHA when available. Treat green CI for an older SHA as stale, not green.
- Local gate is PASS, N/A with rationale, or a clear blocker.
- Open Questions is either `none` or real `OQ-N` IDs. Ignore template placeholders only when obviously not filled, and request cleanup if ambiguous.
- Merge authority is explicit; if missing, default to approval-only unless project rules say reviewers should merge.
- Post-ready pushes include an old SHA → new SHA delta comment; substantive deltas should have a Revision Packet.

## Multiple MR worktree mode

Use when the user supplies multiple MRs, asks for multiple reviews, or asks to review the next N ready MRs.

1. Resolve candidates first. Collect at least IID, title, source branch, target branch, head SHA, author, labels, CI state, linked issue, and changed paths.
2. **Read the builder's `Reviewer Lift > Decoupling proof` from each MR description first.** If every MR in the set has a proof and the proofs are mutually consistent (each lists the others' IIDs and the no-overlap claims align with the changed paths you sampled via raw diff + `git apply --numstat`), accept the proof and skip to the integrity-check below. Only re-derive the proof when (a) one or more MRs have no Decoupling proof, (b) the proofs disagree about co-running IIDs, or (c) sampled changed paths contradict the claimed no-overlap. A set is decoupled only when:
   - MRs target the same default branch and are not stacked on each other;
   - linked issues/MR descriptions have no dependency, ordering, or shared blocker;
   - changed paths and behavior-critical surfaces do not overlap;
   - no shared migrations, schemas, locks, sequencing, deploy topology, generated artifacts, version bumps, or dependency lockfiles;
   - local review/test commands run independently without shared ports, databases, PRO external systems, or mutable global state.
3. If coupling is unclear, review serially in the safest order or ask the user to choose. Never parallelize or batch-approve coupled MRs to save time.
4. Use the original checkout as a coordinator for GitLab queries only. Create one review worktree per MR when local checkout/tests are needed. Do not use shared `FETCH_HEAD` in parallel review mode; fetch each MR into its own temp ref:
   - `git fetch origin +refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>`
   - `git worktree add --detach <path> refs/tmp/review/mr-<iid>`
   - `git -C <path> rev-parse HEAD` must equal MR metadata `sha`; if not, refresh metadata and stop if still mismatched.
5. If the harness provides parallel subagents/worktree orchestration, run one reviewer session per MR/worktree. Review independence requires separate LLM/session context plus separate checkout for local execution.
6. Produce one Review Report and one decision per MR. Do not batch multiple MRs into one GitLab comment, approval, request-changes, or reject action.
7. Approval/merge sequence per MR:
   - re-read MR metadata immediately before approving;
   - approve with `glab mr approve <id> --sha <reviewed-sha>`;
   - merge or queue auto-merge with `--sha <reviewed-sha>` only when `Merge authority` allows it;
   - after merging one MR, re-check remaining MRs' CI and `detailed_merge_status`; if one becomes conflicted/stale, stop that MR and report the blocker instead of forcing.
8. Remove a review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Then delete the temp ref if no other review uses it: `git update-ref -d refs/tmp/review/mr-<iid>`.

## Procedure

1. Resolve the MR(s): supplied IDs/URLs/branches, current-branch MR, or pickup. If multiple, enter **Multiple MR worktree mode** and run the rest independently per MR.
2. Read the linked issue and MR description before the diff (`glab issue view`, `glab mr view`).
3. **Lift the builder's `Reviewer Lift` block.** Copy each field (see `start-build/templates/review-packet.md` for the canonical list) into the matching Review Report fields. If the block is missing or empty (older MRs), record that and re-derive the values yourself; default missing `Merge authority` to approval-only unless project rules say otherwise.
4. Confirm the MR `sha` from `glab mr view <id> -F json` equals the lifted `Reviewed SHA`. If they differ, the builder pushed after marking ready; read the delta note / `Delta since last ready push`, treat the new commits as part of this review, and either re-diff them or request a Revision Packet referencing them before approval.
5. Check labels/status, changed paths, and declared safety-critical surfaces without changing approval eligibility solely due to label absence/mismatch.
6. **Sweep `Reviewer Focus` first** — read those areas hardest before walking the full diff (`glab mr diff <id>`) with the description as a map. Note your findings in the Review Report's `Reviewer Focus Sweep` section even when nothing is wrong.
7. Walk the review categories: scope match, strategy/safety invariants, architecture boundaries, correctness (edges, recovery, exact-decimal math, concurrency, timestamps), tests/evidence, external-API safety (adapters/quirks/redaction), state/DB/migrations (typed models, atomic writes, append-only migrations), observability/ops (metrics, health, runbooks), security/credentials, and engineering quality. For behavior-touching MRs, apply `tdd` test-quality principles when judging evidence.
8. Verify CI status against the lifted `CI pipeline` value: `glab mr view <id> -F json | jq '{mr_sha:.sha,pipeline:.pipeline,merge:.detailed_merge_status}'`, or `glab ci status --branch <source-branch> -F json` for branch pipeline state. When GitLab exposes the pipeline commit SHA, it must equal the reviewed SHA before green CI counts. Flag stale/mismatched CI.
9. Pull and run targeted tests in that MR's worktree when behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution. Do **not** run mutating commands.
10. **Address every `OQ-N` from the MR description in the report's `Open Questions Addressed` section.** For each: answer it, escalate to human, or downgrade to an evidence request. An MR cannot be approved while OQs sit unanswered.
11. Post inline comments for specific lines where useful.
12. Post one top-level **Review Report** comment per MR via `glab mr note create <id> --message "$(cat /tmp/report.md)"` using `templates/review-report.md`. Fill **Reviewer** metadata as `@reviewer — <model-id>` (e.g. `@reviewer — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing.
13. **Re-read MR metadata immediately before approving.** If `sha` no longer matches the SHA you reviewed (builder pushed during your review), re-diff the new commits before approving — never approve a SHA you haven't read.
14. Decide per MR via GitLab controls: approve, request changes, or reject. Approval uses `glab mr approve <id> --sha <reviewed-sha>`. Merge or queue auto-merge for that MR's reviewed SHA only when `Merge authority` allows it.

## Review Report expectations

The report should separate:

- Lifted metadata — all Reviewer Lift fields (see `start-build/templates/review-packet.md`) copied from builder's block, with `verified` annotations
- Reviewer Focus Sweep — what the builder flagged + what you found in those areas
- Open Questions Addressed — one entry per `OQ-N` from the MR description (answer / escalate / evidence request)
- Must Fix (`MF-1`, `MF-2`, ...)
- Should Fix
- Consider
- Praise
- Architectural Observations
- Acceptance Criteria Evidence checked
- Code I Ran / Evidence checked
- TDD / behavior-test evidence checked or marked N/A
- Decision

Every Must Fix names path + line/range + concrete problem + suggested direction if not obvious. Use inline comments for line-anchored findings and reference Must Fix IDs so revision commits can cite them.

## Decisions

- **Approve** — scope matches, no Must Fix remains, all `OQ-N` answered/escalated, tests/evidence adequate, head SHA equals the SHA you reviewed, and CI is green/waived or safely pending (see [BUILD-FLOW.md §Implementation flow](../start-build/BUILD-FLOW.md#implementation-flow) step 9 for the CI-pending auto-merge policy). Run `glab mr approve <id> --sha <reviewed-sha>`. If `Merge authority` allows reviewer-side merge, run `glab mr merge <id> --yes --sha <reviewed-sha>`; if checks are pending and authority allows, run `glab mr merge <id> --auto-merge --yes --sha <reviewed-sha>`. If authority is approval-only/human release, stop after approval and report that. If GitLab blocks approval or merge, report the exact blocker.
- **Request changes** — fixable Must Fix items and the approach is sound. Apply `needs-revision`; keep the MR open.
- **Reject** — premise/architecture/scope is wrong, or a safety boundary is weakened beyond what the user/project accepts. Close the MR with a comment explaining why and what would need to change to reopen. Reject requires human follow-up; don't auto-spawn a revision.

## After review

- **Request changes:** Build agent pushes commits and replies to threads; reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution.
- **Approve:** Reviewer has approved and, when merge authority allowed it, merged or queued auto-merge. Each approved MR has its own reviewed SHA and merge/auto-merge/approval-only result. If a durable summary is required, ensure the MR links are recorded there.
- **Stuck Packet:** post `templates/unblock-response.md` as an MR comment, give short direction, and remove `needs-unblock` when work resumes.

## Template filling guide

This section holds the instructional prose that was previously embedded as HTML comments in the reviewer template files. Read once per session; the templates themselves are now bare skeletons.

### review-report.md

- Post as a single top-level comment on the MR. Use inline review comments for line-anchored findings, and reference each Must Fix item ID (MF-1, MF-2, ...) so revision commits can cite them.
- **Summary** — Overall assessment. If requesting changes, state the headline.
- **Decision** — Approve / Request Changes / Reject. Repeat unambiguously.
- **Must Fix** — Blocking items. Each item: stable ID, path + line/range, problem, and suggested direction if not obvious. Prefix credential/security findings with `[SECURITY]`.
- **Should Fix** — Non-blocking but should be addressed. SF-1, SF-2, ...
- **Consider** — Optional suggestions / preferences / future work. C-1, C-2, ...
- **Safety Checklist** — Pass/fail/N/A for applicable invariants: domain envelope preserved; PRO external-system mutations only via approved adapters; observe/enforce or dry-run/production gates intact; protective sequencing intact; coordination primitive (lease/lock) acquired and not force-stolen; immutable baselines and monotonic invariants preserved; exact-decimal numeric type for money/quantity/domain math; pure engines side-effect free.
- **State / Migration / Persistence Checklist** — Typed models, atomic writes, append-only migrations, transactional events, CLI/interop contracts.
- **External-System and Credential Checklist** — No live mutation, adapter-only calls, fake/recorded HTTP tests, redaction, secrets untouched.
- **Tests and Evidence Reviewed** — Builder evidence accepted/rejected; tests you ran; CI status. Note whether CI pipeline SHA matches Reviewed SHA when GitLab exposes it.
- **Acceptance Criteria Evidence Checked** — For each acceptance criterion from the MR/issue, state accepted evidence or gap.
- **TDD / Behavior-Test Evidence** — Behavior-touching MR: public interface tested? RED/GREEN trace present or reasonably N/A? Tests avoid implementation coupling? Non-behavior MR: "N/A".
- **Code I Ran** — Exact read-only commands and concise result, or "None". Never paste secrets or run mutating PRO commands.
- **Reviewer Focus Sweep** — What the builder flagged in Reviewer Lift > Reviewer Focus, and what you found when you read those areas first. "None flagged" if the builder did not name any.
- **Open Questions Addressed** — One subsection per OQ-N from the MR description. Either answer it, defer to human (and say so), or downgrade to an evidence request. Unanswered OQs cannot sit silently.
- **Praise** — Required. Call out good work / patterns to reinforce.
- **Architectural Observations** — Broader patterns, ADR suggestions, or rejection rationale.
- **Follow-ups for Other Tasks** — Items not blocking this MR. Open separate issues and link them.
- **Final Notes** — Short.

### unblock-response.md

- Use when responding to a Stuck Packet. Post as an MR comment. When Builder resumes, remove the `needs-unblock` label.
- **Summary** — One paragraph: your read and the recommended direction.
- **Direction** — Pointer / correction / pair / escalation. Cite files, tests, docs, or commands.
- **Safety notes** — Any PRO external-system / credential / state precautions before continuing.
- **What I did not check** — Honest scope.
- **Confidence** — High / medium / low and why.

### adr.md

See [templates/filling-guide.md](../templates/filling-guide.md) for ADR template filling instructions.
