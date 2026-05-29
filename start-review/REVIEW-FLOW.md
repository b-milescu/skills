# Start Review Flow

Detailed workflow for `start-review`. Read before selecting MR(s), commenting, approving, merging, requesting changes, rejecting, or reporting a blocked review. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide or `gitlab-local` for direct `glab` command syntax and flag pitfalls.

## Review modes

1. **Fresh-session reviewer** — fresh agentic session loaded with the MR URL, Reviewer Lift pointer, and project rulebook. Single-MR is the default and preferred shape: one MR per fresh reviewer session. Triggered by a human, a parent orchestrator after child `mr-builder` final handoff, a separate builder session, or the [Mandatory review gate](../start-build/BUILD-FLOW.md#mandatory-review-gate) (the default invocation when standalone `/start-build` completes implementation). The Mandatory review gate trigger uses a minimal structured handoff: MR URL + pointer to the Reviewer Lift block in the MR description + project rulebook path + the instruction that parent/builder reasoning is not evidence. In all cases, the reviewer applies the [Context Firewall](#context-firewall), reads the diff fresh, fills the [Review Context Capsule](#review-context-capsule), runs its own tests when needed, and makes its own judgment.
2. **Human reviewer** — when the user wants human judgment or project rules require it.

Builder and reviewer may share the same GitLab account/PAT — review independence comes from session/context separation, not GitLab identity. A single reviewer session cannot provide separate LLM contexts for several MRs; review independence for parallel work requires separate LLM/session context plus separate checkout per MR. The review judgment is the `Review verdict` (`pass / request-changes / reject / blocked`). GitLab side effects are separate: `Approval action`, `Finish action`, `Action blocker`, and `Next action`. Approval is reviewer-driven and requires explicit authority plus a verifiable `Merge authority source`. Explicit `approval-only` is valid: the reviewer may approve with the reviewed SHA, then stop before merge or auto-merge when the source verifies it. Merge immediately or queue auto-merge only when the quoted `Merge authority` and verified source allow it. If `Merge authority` or `Merge authority source` is missing, contradictory, or ambiguous, post the Review Report with `Review verdict: blocked`, `Approval action: blocked`, `Finish action: none`, and `Action blocker: missing-authority`; take no approval, merge, auto-merge, or close action. For multiple MRs, review verdicts and actions happen independently per MR.

## Authority source precedence

`Merge authority` in the Review Packet is a builder-quoted claim, not a grant. The reviewer verifies `Merge authority source` before any approval, merge, or auto-merge action. Accepted sources include parent task prompt, human MR comment URL, rulebook path+section, or project default source. Explicit human or parent instruction beats rulebook/project default. When sources conflict, choose the most restrictive/no action path and report `Review verdict: blocked` with `Action blocker: missing-authority` unless a human/parent resolves it. `reviewer may merge`, `queue auto-merge`, and `project default: ...` without a verifiable source are blocked as missing authority.

## Context Firewall

Review independence is a session/context boundary, not a GitLab account boundary. A session that built, planned, revised, or parent-orchestrated the MR cannot provide gate-eligible review for that same MR. Same-session review can only be advisory: it may list hypotheses, likely risks, or suggested reviewer focus, but it must not post a gate-eligible Review Report, approve, merge, queue auto-merge, close, or claim the mandatory review gate is complete.

Treat parent, builder, planner, and reviser reasoning as unverified claims. Do not treat parent/builder reasoning, hidden conversation history, run logs, or local handoff prose as evidence for correctness, safety, authority, CI, scope, or merge readiness. The reviewer may use such material only as a pointer to Tier 1 or Tier 2 evidence, then must verify from GitLab MR metadata, the diff, linked issue, project rulebook, CI, local checks, or directly referenced docs/tests before deciding.

If inherited context includes builder or parent analysis beyond the minimal launch prompt, preserve the firewall: ignore it by default, do not cite it as evidence, and record any use as a claim in the Review Context Capsule with an independent verification/source. If the reviewer cannot separate inherited builder/parent reasoning from the review judgment, report `Review verdict: blocked`, `Action blocker: human-decision-needed`, and `Next action: rerun-review` in a fresh session.

### Context tiers

| Tier | Name | Default handling | Examples |
|---|---|---|---|
| Tier 0 | prompt invariants | Always honor as task bounds, not proof of MR behavior. | Reviewer role, MR URL, Reviewer Lift pointer, project rulebook path, explicit human/parent authority instruction, safety invariants. |
| Tier 1 | required reads | Read before the diff/verdict; these are the normal evidence base. | Bound MR metadata, MR description/Reviewer Lift, linked issue, project rulebook, full diff, changed paths, CI metadata, Review Context Capsule. |
| Tier 2 | risk-triggered reads | Read only when concrete diff, test, CI, safety, or review evidence creates a need; record the trigger/source. | Direct callers/imports, adjacent tests/docs, ADRs for touched areas, revision packets, CI logs, failing command output, relevant issue/MR comments. |
| Tier 3 | forbidden-by-default broad context | Do not read or rely on unless a human explicitly asks or Tier 2 evidence proves the broad context is required; record why. | Whole repo sweeps, old parent conversation, builder planning logs, broad memory recall, unrelated issues/MRs, unbounded grep, unrelated run artifacts. |

Tier 3 broad context includes whole repo sweeps and old parent conversation; treat both as forbidden by default unless concrete risk evidence or explicit human instruction requires them.

## Review Context Capsule

Fill a Review Context Capsule before the final verdict and keep it aligned with the Review Report. The capsule distinguishes `Claim`, `Reviewer verification`, and `Source` so the reviewer can use handoff data as a map, not truth. A claim may come from the Reviewer Lift, parent prompt, MR description, issue, CI, or local artifact. Verification is the reviewer's independent check. Source is the exact path, URL, command output, comment, or rulebook section that backs the verification.

| Capsule field | Claim to capture | Reviewer verification required | Source to cite |
|---|---|---|---|
| Repo | Host, project path, repo URL, default/target branch, and whether cross-repo review was explicitly chosen. | `gitlab-local` preflight and project binding match the supplied MR, or mismatch is blocked/explicitly chosen. | `local-repo-preflight`, `git remote -v`, supplied MR URL, project rulebook. |
| MR | MR IID/URL, source branch, target branch, current head SHA, linked issue, and draft/readiness state. | Decision-grade MR metadata matches `Reviewed SHA`; changed-head handling is recorded if not. | `mr-pickup`, Review Packet, MR diff artifact. |
| Authority | `Merge authority` and `Merge authority source` claim. | Source exists, precedence is applied, conflicts choose most restrictive/no action, and chosen approval/finish action is allowed. | Reviewer Lift row plus parent task prompt, human MR comment URL, rulebook path+section, or project default source. |
| CI | Builder CI row, current pipeline ID/URL/status/SHA, and local gate claim. | Pipeline is classified with the CI decision table for the reviewed SHA; local gate evidence is accepted, rerun, or blocked. | MR metadata, `ci-decision-snapshot`, CI URL/logs when needed, local command output. |
| Scope | Issue acceptance criteria, declared safety surfaces, changed paths, and non-goals. | Diff matches the issue and rulebook; scope creep and safety-surface mismatches are findings/blockers. | Linked issue, MR description, diff, rulebook, directly referenced docs/tests. |
| Artifacts | Review Packet, Reviewer Lift, revision packets, build/test artifacts, and local run paths the builder cites. | Artifacts exist, are relevant, redacted, and support the specific claim; missing artifacts become evidence gaps. | MR description/comments, artifact paths, command transcripts, test output. |
| Context expansion | Tier 2/Tier 3 context the reviewer used or considered. | Each expansion has a concrete risk trigger and stays bounded; Tier 3 use has explicit human instruction or recorded necessity. | Path/line, finding ID, failing command, CI log, human instruction, or rulebook section that triggered expansion. |

Safety-critical fields require reviewer verification and source before they can support a pass or action: MR head/`Reviewed SHA`, CI pipeline, local gate, changed paths, touched safety surfaces, decoupling proof, Open Questions, `Merge authority`, `Merge authority source`, and post-ready delta comments.

## Fail-closed review coverage

A reviewer must never partially approve a diff. If the reviewer cannot inspect all behavior-affecting changed surfaces, stop the pass path: use `Review verdict: blocked` with `Action blocker: partial-review` when the review cannot continue safely, or `request-changes` when the builder can fix the evidence gap by splitting the MR, removing an opaque artifact, or adding provenance/context. Request split when one MR is too broad for a bounded review. Do not approve, merge, or queue auto-merge until every behavior-affecting changed surface has been inspected or the MR has been split.

Partial-review triggers include: diff unavailable; too large for bounded review; binary/generated artifact without provenance; hidden dependencies; missing linked issue/context affecting behavior; or tool limits before decision. Treat unknown trigger state as fail-closed rather than approving the visible subset.

Suspected secret exposure is a security blocker, not report content. If a diff, log, artifact, or comment appears to expose a secret or credential, do not quote the secret or credential value, do not copy the sensitive payload into comments/templates/final handoffs, and redact the Review Report with `[REDACTED]` plus path/line or artifact locator only. Block approval with `Action blocker: secret-exposure-suspected`; require removal from the MR plus rotation/revocation and history purge guidance, or human security escalation, per project policy. Do not prescribe organization-specific rotation commands unless the project policy explicitly provides them.

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

Reviewers load the small `gitlab-local` review cards before the full command reference where possible:

- [`review-read`](../gitlab-local/reference/review-read.md) — preflight, issue/MR metadata, project binding reads, and artifact capture.
- [`ci`](../gitlab-local/reference/ci.md) — CI snapshots, exact-SHA CI waiting, and fail-closed CI verdict rules.
- [`review-actions`](../gitlab-local/reference/review-actions.md) — MR notes, issue-note target split, SHA guards, approval, merge, auto-merge queueing, approval confirmation, and authority-aware finish.

The cards carry snippet names, inputs/outputs, and fail-closed rules without copying raw command bodies. Full command ownership still lives in the host project's issue-tracker guide or [`gitlab-local/SKILL.md`](../gitlab-local/SKILL.md): fall back to [`gitlab-local/SKILL.md`](../gitlab-local/SKILL.md) when a card is missing/ambiguous, live CLI help or JSON shape drifts, a needed command is not carded, non-review issue/MR operations are required, or helper behavior needs troubleshooting. This flow names commands only where sequencing matters, and keeps SHA-bound approval, merge, auto-merge queueing, and approval confirmation choices visible at action points.

## Project binding

Every supplied MR URL, IID/ID, or branch name must be project-bound after
`gitlab-local` **Snippet: local-repo-preflight** and before MR pickup continues.
Before any MR comment, approval, merge, auto-merge, or close-equivalent action,
the reviewer must resolve one bound MR record and use it for comments,
approvals, merge, auto-merge, or close-equivalent actions.

Bound fields:

- `bound_host` — GitLab host from the supplied MR URL or preflight repo.
- `bound_project_path` — namespace/project path, for example `agents/skills`.
- `bound_repo_url` — explicit repo target accepted by `gitlab-local` snippet commands.
- `bound_mr_iid` — project-scoped MR IID.
- `bound_mr_url` — canonical full MR URL for reports and URL-based commands.
- `bound_source_branch` — source branch from decision-grade MR metadata.
- `bound_target_branch` — target branch from decision-grade MR metadata.
- `bound_current_sha` — current MR head SHA from decision-grade metadata.

Resolution rules:

1. For a full MR URL, parse host, project path, and IID from the URL, then
   re-read MR metadata through the full MR URL or `-R "$bound_repo_url"`.
2. For a bare IID/ID or branch, bind it to the preflight repo only, then
   re-read MR metadata with `-R "$bound_repo_url"` before trusting it.
3. Compare `bound_host` and `bound_project_path` to the preflight repo. A mismatch blocks unless the user explicitly chooses the cross-repo review target; record that choice in the Review Report and final handoff before any GitLab mutation.
4. Command rule: every decision-grade MR read and every GitLab mutation uses an
   explicit repo target or full MR URL. Prefer the bound MR IID plus
   `bound_repo_url`; use the full MR URL when a URL was supplied or repo
   inference remains uncertain. Never use cwd-inferred bare IID action guidance
   for notes, approvals, merges, auto-merge queueing, or close-equivalent
   actions.

This binding rule is compatible with file-backed Review Reports and action-result
notes; use `gitlab-local` **Snippet: mr-note-create** for MR notes after binding
and keep issue-note commands out of review-report posting paths.

## MR pickup

When the user supplies an MR ID/URL/branch, review it only after the
[Project binding](#project-binding) check succeeds. Otherwise pick one MR from
the **current GitLab project**. When the user supplies or requests multiple MRs,
do not treat one reviewer session as several independent review contexts: prefer
parent/harness fanout into one fresh reviewer session per MR/worktree, or enter
explicit serialized mode only after the set satisfies the shared
[Decoupling Contract](../docs/decoupling-contract.md):

1. Run `gitlab-local` **Snippet: local-repo-preflight** to confirm `glab` resolves to the cwd repo. If preflight fails, post/report `Review verdict: blocked` with `Action blocker: preflight-failure` when an MR context exists; otherwise stop and ask.
2. Bind supplied MR references to the preflight repo, or block on cross-repo mismatch until the user explicitly chooses the cross-repo review target.
3. If the current branch has an MR (use `gitlab-local` **Snippet: mr-pickup**), prefer it when the user says "this branch" or the branch is clearly under review.
4. Otherwise list open non-draft MRs with `gitlab-local` **Snippet: mr-pickup**. Narrow with `-l/--label`, `-a/--assignee=@me`, `-r/--reviewer=@me`, `-t/--target-branch` as needed. Prefer MRs labeled with the project's ready-for-review equivalent, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
5. Deprioritize drafts, blocked MRs, MRs labeled with the project's revision/unblock/WIP equivalent, and obviously red-CI MRs unless the user asked for failure triage.
6. Inspect the selected candidate, or 3-5 candidates when selecting among MRs. For multiple requested MRs, inspect enough to validate coupling. Don't dump raw JSON; summarize MR ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
7. If one MR is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user or parent to choose between separate reviewer-session fanout and explicit serialized mode.
8. For multiple supplied/requested MRs, prefer the builder's `Reviewer Lift > Decoupling proof` from each MR description and apply the [Decoupling Contract's reviewer consumer guidance](../docs/decoupling-contract.md#reviewer-consumer-guidance). If proof is absent, insufficient, inconsistent, or contradicted by evidence, collect changed paths with `gitlab-local` **Snippet: artifact-capture** (or the GitLab changes API) before declaring the set decoupled. Decoupling Contract proof is required before parent parallel fanout.

## Handoff integrity check

Before reading the full diff, validate the builder handoff:

- Project binding has a complete bound MR record (host, project path, repo URL, IID, source branch, target branch, and current SHA), and the bound MR URL/project is recorded for the Review Report and final handoff.
- Reviewer Lift exists and its rows match `start-build/templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema, and the Review Report derives the same rows. Treat the Reviewer Lift as a map, not truth: every safety-critical field needs reviewer verification and source before it can support the verdict or an approval/finish action.
- Review Context Capsule has repo, MR, authority, CI, scope, artifacts, and context-expansion rows with claim, verification, and source values, or the report explains why review blocked before completion.
- MR head SHA equals `Reviewed SHA`. If not, read the delta note/revision packet and re-diff the new commits before approval. If you cannot safely review the new head, report `Review verdict: blocked` with `Action blocker: changed-head-sha`.
- CI pipeline evidence includes URL/ID, status, and commit SHA when available. Classify it with the [CI decision table](#ci-decision-table) before any approval or finish action.
- Local gate is PASS, N/A with rationale, or a clear blocker.
- Open Questions is either `none` or real `OQ-N` IDs. Ignore template placeholders only when obviously not filled, and classify real questions with the [Open Question decision table](#open-question-decision-table).
- Merge authority is explicit and treated as a quoted builder claim, not a grant. `Merge authority source` is mandatory and verifiable; if authority or source is missing, contradictory, unverifiable, or ambiguous, block approval/merge/close actions and report `Action blocker: missing-authority`. Explicit `approval-only` is valid when its source verifies it and means approval may proceed after normal guards, but merge/auto-merge may not.
- Post-ready pushes include an old SHA → new SHA delta comment; substantive deltas should have a Revision Packet.

## Multiple MR worktree mode

Use only when the user supplies multiple MRs, asks for multiple reviews, or asks to review the next N ready MRs. Default/preferred behavior remains one MR per fresh reviewer session. A single reviewer session cannot provide separate LLM contexts for multiple MRs.

1. Resolve candidates first. Collect at least IID, title, source branch, target branch, head SHA, author, labels, CI state, linked issue, and changed paths.
2. **Read the builder's `Reviewer Lift > Decoupling proof` from each MR description first.** Apply the [Decoupling Contract's reviewer consumer guidance](../docs/decoupling-contract.md#reviewer-consumer-guidance): accept mutually consistent proofs that align with sampled paths and metadata; re-derive when proofs are missing, insufficient, inconsistent, or contradicted by evidence.
3. If coupling is unclear after the contract check, review serially in the safest order or ask the user to choose. Never parallelize coupled work to save time, and never group approvals or finish actions for coupled MRs.
4. Parallel multiple-MR review requires parent/harness-provided separate sessions and worktrees: one reviewer session per MR/worktree. Use the original checkout as a coordinator for GitLab queries only. Create one review worktree per MR when local checkout/tests are needed. Do not use shared `FETCH_HEAD` in parallel review mode; fetch each MR into its own temp ref:
   - `git fetch origin +refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>`
   - `git worktree add --detach <path> refs/tmp/review/mr-<iid>`
   - `git -C <path> rev-parse HEAD` must equal MR metadata `sha`; if not, refresh metadata and stop if still mismatched.
5. If a parent/harness has already provided parallel reviewer sessions and worktrees, keep one reviewer session per MR/worktree. If you are running inside a reviewer child session, review only the assigned MR/worktree and do not launch sibling reviewers. Review independence requires separate LLM/session context plus separate checkout for local execution.
6. Explicit serialized mode does not batch decisions, comments, or actions: finish one MR's Review Report, `Review verdict`, reviewed SHA, action result, and final handoff before starting the next MR.
7. Produce one Review Report, one `Review verdict`, and one reviewed SHA per MR. Do not group multiple MRs into one GitLab comment, approval, request-changes, reject, or blocked action.
8. Approval/merge sequence per MR:
   - re-run `gitlab-local` **Snippet: sha-guard** immediately before any approval, merge, or auto-merge action; the decision point must visibly bind the reviewed head and project by resolving the current SHA from `bound_mr_iid` plus `bound_repo_url` (or `bound_mr_url`) and comparing it to `reviewed_sha`;
   - approve with `gitlab-local` **Snippet: sha-bound-approval** only when approval is authorized, using the bound MR IID plus `-R "$bound_repo_url"` or the full `bound_mr_url`;
   - confirm approval with `gitlab-local` **Snippet: approval-confirmation** when approval status must be verified;
   - before direct merge, re-run a fresh SHA guard immediately before direct merge, then use `gitlab-local` **Snippet: sha-bound-merge** only when direct merge is authorized;
   - before queueing auto-merge, re-run a fresh SHA guard immediately before the auto-merge queue action, then use `gitlab-local` **Snippet: sha-bound-auto-merge-queue** only when queueing auto-merge is authorized;
   - choose one action at each authorization point; never run a combined approval/merge block or paste multiple action snippets as one executable sequence;
   - if SHA-bound approval/merge flags are unavailable or unsupported, report `Review verdict: blocked` with `Action blocker: sha-bound-action-unsupported` rather than taking an unpinned action;
   - after merging one MR, re-check remaining MRs' CI and `detailed_merge_status`; if one becomes conflicted/stale, stop that MR and report the blocker instead of forcing.
9. Remove a review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Then delete the temp ref if no other review uses it: `git update-ref -d refs/tmp/review/mr-<iid>`.

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

1. Resolve and project-bind the MR: supplied ID/URL/branch, current-branch MR, or pickup. If multiple MRs are explicitly supplied/requested, enter **Multiple MR worktree mode** only after choosing parent/harness-provided separate reviewer sessions/worktrees or explicit serialized mode; run the rest independently per MR. Do not continue to comments, approvals, merge, auto-merge, or close-equivalent actions until each MR has a bound host, project path, repo URL, IID, source branch, target branch, and current SHA.
2. Read the linked issue and MR description before the diff using `gitlab-local` **Snippet: issue-pickup** and **Snippet: mr-pickup** with the bound MR URL or explicit repo target. Apply the [Context Firewall](#context-firewall) and [context tiers](#context-tiers): Tier 1 reads are required; Tier 2 reads need concrete risk triggers; Tier 3 broad context is forbidden by default.
3. **Lift the builder's `Reviewer Lift` block as a map, not truth.** Copy each field from `start-build/templates/reviewer-lift-schema.md` into the matching Review Report fields, then verify safety-critical fields from independent sources before relying on them. If the block is missing or empty (older MRs), record that and re-derive non-authority values yourself; do not infer authority. Missing, contradictory, or ambiguous `Merge authority` or `Merge authority source` blocks approval/merge/close actions until the Review Packet, parent task prompt, human MR comment URL, rulebook path+section, or project default source supplies explicit authority; if no authority can be obtained during review, use `Review verdict: blocked` and `Action blocker: missing-authority`. Apply authority source precedence from this flow: explicit human or parent instruction beats rulebook/project default, builder claims do not grant authority, and conflicts choose the most restrictive/no action path.
4. Confirm the MR `sha` from `gitlab-local` **Snippet: mr-pickup** using the bound MR URL or `-R "$bound_repo_url"` equals the lifted `Reviewed SHA`. If they differ, the builder pushed after marking ready; read the delta note / `Delta since last ready push`, treat the new commits as part of this review, and either re-diff them or request a Revision Packet referencing them before approval. If safe re-review is not possible, report `Action blocker: changed-head-sha`.
5. Check labels/status, changed paths, and declared safety-critical surfaces without changing approval eligibility solely due to label absence/mismatch.
6. **Sweep `Reviewer Focus` first** — read those areas hardest before walking the full diff with `gitlab-local` **Snippet: artifact-capture** as needed. Note your findings in the Review Report's `Reviewer Focus Sweep` section even when nothing is wrong.
7. Walk the review categories: scope match, strategy/safety invariants, architecture boundaries, correctness (edges, recovery, exact-decimal math, concurrency, timestamps), tests/evidence, external-API safety (adapters/quirks/redaction), state/DB/migrations (typed models, atomic writes, append-only migrations), observability/ops (metrics, health, runbooks), security/credentials, the fail-closed partial-review/secret-exposure rules, and the bounded structural maintainability sweep. For behavior-touching MRs, apply `tdd` test-quality principles when judging evidence.
8. Fill the [Review Context Capsule](#review-context-capsule) with claim, reviewer verification, and source entries for repo, MR, authority, CI, scope, artifacts, and context expansion. Keep parent/builder reasoning as a claim only; cite Tier 1/Tier 2 evidence for verification.
9. Verify CI status against the lifted `CI pipeline` value with `gitlab-local` **Snippet: ci-decision-snapshot**, then classify it with the [CI decision table](#ci-decision-table).
10. When local execution is needed because behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution, enter **Single MR checkout mode** first for one MR (or the existing multiple-MR worktree path for multiple MRs), then run targeted tests only from the verified exact-SHA checkout. Do **not** run mutating commands.
11. **Address every `OQ-N` from the MR description in the report's `Open Questions Addressed` section.** Classify each question with the [Open Question decision table](#open-question-decision-table) before choosing the review verdict or action fields.
12. Post inline comments for specific lines where useful.
13. **Draft the Review Report before final guards.** Normative report/action order: draft Review Report -> final MR/CI/authority snapshot -> convert to blocked if any guard fails -> post Review Report -> SHA guard before approval -> authorized action -> optional action-result note/final handoff. Fill **Reviewer** metadata as `@reviewer — <model-id>` (e.g. `@reviewer — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing. In the draft, action fields describe the intended action when approval/merge/auto-merge will happen after posting; they must not claim completed GitLab side effects before those effects are verified.
14. **Take the final MR/CI/authority snapshot before posting.** Re-read bound MR metadata, current head SHA, pipeline SHA/status, `detailed_merge_status`, explicit `Merge authority`, and verifiable `Merge authority source` using the bound MR URL or explicit repo target. If a final guard fails, convert the drafted report to `Review verdict: blocked`, set the appropriate `Action blocker`, set approval/finish actions to blocked or none, and only then post the report. Do not post a pass report whose own final snapshot is already stale, red, missing authority, wrong-project-bound, or otherwise blocked.
15. Post one top-level **Review Report** comment per MR with `gitlab-local` **Snippet: mr-note-create** using `templates/review-report.md` and the bound MR URL or explicit repo target. Fill `Review verdict`, `Approval action`, `Finish action`, `Action blocker`, and `Next action` before posting, using intended-action wording for post-report actions and completed-action wording only for side effects already verified. Redact suspected secret findings before posting; use `[REDACTED]`, path/line or artifact locator, and the `secret-exposure-suspected` blocker token instead of copying sensitive values.
16. **Re-run `gitlab-local` Snippet: sha-guard immediately before approving.** The action point must visibly resolve the current SHA from `bound_mr_iid` plus `bound_repo_url` and compare it with `reviewed_sha`; use the full `bound_mr_url` instead when that is the safer locator. If the head SHA changes after the report is posted but before action, skip approval, merge, and auto-merge; the optional action-result note or final handoff reports the stale SHA, current SHA, reviewed SHA, bound MR URL/project, `Action blocker: changed-head-sha`, and `Next action: rerun-review`. Never approve a SHA you haven't read.
17. Apply the posted Review Report outcome. `pass` may proceed to a separate, authorized approval action after the post-report SHA guard. `request-changes` keeps the MR open for builder revision. `reject` is non-mutating by default: do not close the MR unless explicit human/project close authority says to close it. `blocked` takes no approval, merge, auto-merge, or close action; route by `Action blocker` and `Next action`. Permission failures during approval/merge map to `Action blocker: permission-failure`; record the failed action in the final handoff and, when useful for durable MR history, an action-result note.
18. **Guard before each finish action.** Before direct merge, re-run a fresh SHA guard immediately before direct merge, then use `gitlab-local` **Snippet: sha-bound-merge** only when direct merge is authorized and targeted at the bound MR URL or explicit repo target. Before queueing auto-merge, re-run a fresh SHA guard immediately before the auto-merge queue action, then use `gitlab-local` **Snippet: sha-bound-auto-merge-queue** only when queueing is authorized and targeted at the bound MR URL or explicit repo target. If the head changed, skip that finish action and report `changed-head-sha` in the action-result note/final handoff rather than acting on the stale report.
19. **Final reviewer handoff.** After posting the Review Report and after any authorized approval, merge, or auto-merge action attempt, the final response MUST include the machine-readable block from `templates/reviewer-final-handoff.md` when that template is available. Fill it with the same verdict/action vocabulary as the Review Report: bound MR URL/project, `review_verdict` (`pass / request-changes / reject / blocked`), `reviewed_sha`, pipeline status/SHA, local checks, `MF-N` / `SF-N` / `C-N` finding IDs, Open Question handling, `merge_authority`, `merge_authority_source`, `approval_action`, `finish_action`, `action_blocker`, `next_action`, and `report_url` or `N/A`. Keep the GitLab Review Report comment as the durable review record; the final handoff is a parseable session artifact for parent orchestrators and records completed action results after post-report action attempts. If the template is unavailable, say so and still return those verified fields in prose/YAML; do not invent MR, CI, approval, action, blocker, or report-link state.

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

## Review tone

When you raise a structural maintainability finding, raise it plainly: name the
smell, the `file:line`, and the bounded remedy. Do not dilute a real, blocking
maintainability problem into a mild "maybe consider," and do not wave a change
through just because it works when it leaves the surrounding code harder to
reason about — say so directly. Be demanding about complexity; do not be
demanding about taste.

Tone never moves the bar. Taste, naming, and formatting stay `C-N`/non-blocking
per the decision rule above; the demanding voice applies only to findings that
already qualify as `MF-N` — material structural complexity with a bounded remedy
inside the MR's blast radius. For an ambitious whole-design reframing that
reaches beyond the diff, record a `C-N`/follow-up for a dedicated architecture
pass rather than expanding this MR.

## Review Report expectations

See [templates/filling-guide.md §review-report.md](templates/filling-guide.md#review-reportmd) for the canonical list of report sections and per-section guidance. Every Must Fix names path + line/range + concrete problem + suggested direction if not obvious. Use inline comments for line-anchored findings and reference Must Fix IDs so revision commits can cite them.

## Decisions

- **Pass** — scope matches, no Must Fix remains (including no blocker-level structural maintainability regression), every behavior-affecting changed surface was inspected, every `OQ-N` is classified as pass-eligible by the [Open Question decision table](#open-question-decision-table), tests/evidence are adequate, bound MR project is verified against the preflight repo or explicit cross-repo target, head SHA equals the SHA you reviewed, `Merge authority` is explicit, `Merge authority source` is verifiable, and CI is pass-eligible by the [CI decision table](#ci-decision-table). Re-run `gitlab-local` **Snippet: sha-guard** using an explicit repo target or full MR URL, then choose the authorized action against that same bound target: `gitlab-local` **Snippet: sha-bound-approval** for approval, **Snippet: approval-confirmation** to verify approval when needed, **Snippet: sha-bound-merge** for direct merge, or **Snippet: sha-bound-auto-merge-queue** for protected auto-merge queueing. If authority is approval-only/human release, stop after approval and report that as the Finish action. `pass` does not imply approval happened; `Approval action` says whether it did.
- **Request changes** — fixable Must Fix items and the approach is sound. Apply the project's revision label if one exists; keep the MR open.
- **Reject** — premise/architecture/scope is wrong, or a safety boundary is weakened beyond what the user/project accepts. Post the Review Report with the reject verdict, explain why and what would need to change before a new or continued MR can proceed, then stop and escalate to the parent/human. Leave the MR open by default; closing an MR requires explicit human/project close authority. Reject requires human follow-up; don't auto-spawn a revision.
- **Blocked** — guard/tool/authority/security state prevents a safe approval or finish without judging the code as fixable or invalid. Use `Approval action: blocked` or `not-approved`, `Finish action: none` or `blocked`, and one `Action blocker`: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or `other`. Parent orchestrators route blocked outcomes to authority/CI/tooling/security/human-decision handling, not to builder code revision unless the blocker itself names builder work.

## After review

- **Request changes:** Build agent pushes commits and replies to threads; reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution.
- **Pass:** Reviewer has posted a passing review judgment and separately recorded Approval action and Finish action. Each passing MR has its own reviewed SHA, action result, and final handoff. If a durable summary is required, ensure the MR links are recorded there.
- **Reject:** Review Report is posted and the reviewer stops/escalates to the parent/human. Do not close the MR unless explicit human/project close authority says to close it.
- **Blocked:** Review Report is posted, no approval/merge/close action is taken, and the parent/human routes by `Action blocker` and `Next action`.
- **Stuck Packet:** post `templates/unblock-response.md` as an MR comment with `gitlab-local` **Snippet: mr-note-create**, give short direction, and remove the project's unblock label when one exists and work resumes.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Reviewer template filling guide](templates/filling-guide.md)
- [Shared ADR filling guide](../templates/filling-guide.md)

Safety-critical filling rules are stated in full earlier in this flow; do not restate them here. Use these pointers:

- Context Firewall, context tiers, and "parent/builder reasoning is not evidence" (same-session builder/parent/planner/reviser review is advisory only): [Context Firewall](#context-firewall).
- Reviewer Lift as a map (not truth) plus the safety-critical verification/source requirement and `Reviewed SHA` head match: [Review Context Capsule](#review-context-capsule) and [Handoff integrity check](#handoff-integrity-check).
- CI, Open Question, and stable `OQ-N` classification: [CI and Open Question decision tables](#ci-and-open-question-decision-tables).
- Secret/credential handling, redaction, and `secret-exposure-suspected`: [Fail-closed review coverage](#fail-closed-review-coverage).
- Stable review item IDs (`MF-N`, `SF-N`, `C-N`), follow-up issues for surviving non-blocking findings, and brief-quality defects: [Review Report expectations](#review-report-expectations) and the [Reviewer template filling guide](templates/filling-guide.md).
