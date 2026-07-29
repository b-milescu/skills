# Start Review Flow

Detailed workflow for `start-review`. Read before selecting MR(s), commenting, approving, merging, requesting changes, rejecting, or reporting a blocked review. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide or `gitlab` for MCP-first transport contracts, guarded `glab` fallback syntax, and flag pitfalls.

## Review modes

1. **Fresh-session reviewer** — fresh agentic session loaded with the MR URL, Reviewer Lift pointer, and project rulebook. Single-MR is the default and preferred shape: one MR per fresh reviewer session. Triggered by a human, a parent orchestrator after child `mr-builder` final handoff, a separate builder session, or the [Mandatory review gate](../start-build/reference/standalone-gate.md#mandatory-review-gate) (the default invocation when standalone `/start-build` completes implementation). The Mandatory review gate trigger uses a minimal structured handoff: MR URL + pointer to the Reviewer Lift block in the MR description + project rulebook path + the instruction that parent/builder reasoning is not evidence. In all cases, the reviewer applies the [Context Firewall](#context-firewall), reads the diff fresh, fills the [Review Context Capsule](#review-context-capsule), runs its own tests when needed, and makes its own judgment.
2. **Human reviewer** — when the user wants human judgment or project rules require it.

Builder and reviewer may share the same GitLab account/PAT — review independence comes from session/context separation, not GitLab identity. A single reviewer session cannot provide separate LLM contexts for several MRs; review independence for parallel work requires separate LLM/session context plus separate checkout per MR. The review judgment is the `Review verdict` (`pass / request-changes / reject / blocked`). GitLab side effects are separate: `Approval action`, `Finish action`, `Action blocker`, and `Next action`. Approval authority is distinct from merge authority: a reviewer may approve a passing review by default when the approval policy source verifies, unless an explicit restriction source says otherwise. Merge, auto-merge, release, deploy, close, and source-branch cleanup remain separate finish actions that require explicit merge/finish authority and source.

Authority claim shape, source precedence, conflict/restricted/missing-source
results, action routing, and no-self approval/merge classification are canonical
in [`../gitlab/reference/authority-verification.md`](../gitlab/reference/authority-verification.md).

## Approval authority policy

Reviewer approval is allowed by default after a passing review unless explicitly restricted by a human/parent instruction, MR or issue policy note, project rulebook, or repository policy. The default approval source for this repo is this section (`start-review/REVIEW-FLOW.md#approval-authority-policy`), and projects may cite an equivalent stable rulebook section. Approval still requires all normal guards: complete review coverage, no Must Fix, exact reviewed SHA, pass-eligible CI/local-gate/OQ state, no partial-review or secret-exposure blocker, and a fresh SHA-bound approval guard. A reviewer using the same GitLab account/PAT as the MR author may still approve when the review session is fresh and gate-eligible; same-session builder/parent/planner/reviser review remains advisory-only under the Context Firewall. This approval policy does not grant merge, auto-merge, release, deploy, close, or cleanup authority.

## Merge authority source precedence

`Merge authority` in the Review Packet is a builder-quoted finish-authority claim, not a grant. The reviewer verifies `Merge authority source` through the canonical [Authority Verification](../gitlab/reference/authority-verification.md) seam before any merge, auto-merge, release, close, cleanup, or other finish action. Accepted sources include parent task prompt, human MR comment URL, rulebook path+section, or project default source. Explicit human or parent instruction beats rulebook/project default. When sources conflict, choose the most restrictive/no-action finish path and report `Action blocker: missing-authority` for finish unless a human/parent resolves it. `reviewer may merge`, `queue auto-merge`, and `project default: ...` without a verifiable source are blocked as missing finish authority. Explicit `approval-only` is valid when its source verifies it and means approval may proceed after normal guards while finish stops before merge/auto-merge. Parent-managed reviewer launches carry literal `Finish owner: parent`; in that mode the reviewer owns only Review Report verdict/evidence, records `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, `Next action: finish-by-authorized-actor`, and hands finish back to parent/authorized finisher.

## Context Firewall

Review independence is a session/context boundary, not a GitLab account boundary. A session that built, planned, revised, or parent-orchestrated the MR cannot provide gate-eligible review for that same MR. Same-session review can only be advisory: it may list hypotheses, likely risks, or suggested reviewer focus, but it must not post a gate-eligible Review Report, approve, merge, queue auto-merge, close, or claim the mandatory review gate is complete.

Treat parent, builder, planner, reviser, Gate Receipt comments, and compact `delivery.kind=gitlab-delivery` values as unverified claims. Do not treat parent/builder reasoning, Gate Receipt prose, compact delivery fields, hidden conversation history, run logs, or local handoff prose as evidence for correctness, safety, authority, CI, scope, or merge readiness. The reviewer may use such material only as a pointer to Tier 1 or Tier 2 evidence, then must verify from GitLab MR metadata, the diff, linked issue, project rulebook, CI, local checks, the canonical Gate Receipt seam (`../start-build/reference/parent-owned-gate.md`), or directly referenced docs/tests before deciding.

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
| Repo | Host, project path, repo URL, default/target branch, and whether cross-repo review was explicitly chosen. | `gitlab` preflight and project binding match the supplied MR, or mismatch is blocked/explicitly chosen. | `local-repo-preflight`, `git remote -v`, supplied MR URL, project rulebook. |
| MR | MR IID/URL, source branch, target branch, current head SHA, linked issue, and draft/readiness state. | Decision-grade MR metadata matches `Reviewed SHA`; changed-head handling is recorded if not. | `mr-pickup`, Review Packet, MR diff artifact. |
| Authority | `Approval authority`/source and `Merge authority`/source claims. | Verify through [`../gitlab/reference/authority-verification.md`](../gitlab/reference/authority-verification.md): approval policy or restriction separately from merge/finish authority; source precedence; conflicts choose most restrictive/no-action for the affected action; no-self context is classified separately from GitLab account equality. | Reviewer Lift rows plus parent task prompt, human MR comment URL, rulebook path+section, repository approval policy, or project default source. |
| CI | Builder CI row, current pipeline ID/URL/status/SHA, local gate claim, and any parent Gate Receipt claim. | Pipeline is classified with the CI decision table for the reviewed SHA; local gate evidence or Gate Receipt is accepted, rerun, or blocked using the canonical parent-owned gate seam. | MR metadata, `ci-decision-snapshot`, CI URL/logs when needed, Gate Receipt MR comment, `../start-build/reference/parent-owned-gate.md`, local command output. |
| Scope | Issue acceptance criteria, declared safety surfaces, changed paths, and non-goals. | Diff matches the issue and rulebook; scope creep and safety-surface mismatches are findings/blockers. | Linked issue, MR description, diff, rulebook, directly referenced docs/tests. |
| Artifacts | Review Packet, Reviewer Lift, revision packets, build/test artifacts, and local run paths the builder cites. | Artifacts exist, are relevant, redacted, and support the specific claim; missing artifacts become evidence gaps. | MR description/comments, artifact paths, command transcripts, test output. |
| Context expansion | Tier 2/Tier 3 context the reviewer used or considered. | Each expansion has a concrete risk trigger and stays bounded; Tier 3 use has explicit human instruction or recorded necessity. | Path/line, finding ID, failing command, CI log, human instruction, or rulebook section that triggered expansion. |

Safety-critical fields require reviewer verification and source before they can support a pass or action: MR head/`Reviewed SHA`, Gate owner, Gate coverage/rationale, CI pipeline, local gate, changed paths, touched safety surfaces, decoupling proof, Open Questions, `Approval authority`, `Approval authority source`, `Merge authority`, `Merge authority source`, and post-ready delta comments.

A Gate Receipt is a claim/source pointer, not independent review evidence. Its schema and parent verification checklist are canonical in `../start-build/reference/parent-owned-gate.md`. When a parent-owned gate was used, reviewers still verify safety-critical SHA, Gate coverage, CI, local gate, and authority fields from Tier 1/Tier 2 sources before approval or finish action; a missing, stale, wrong-SHA, or preflight-failed Gate Receipt blocks the pass path.

Builder readiness and Gate coverage do not authorize approval, merge, or auto-merge. Reviewer-side CI approval/finish eligibility remains exclusively governed by the [CI decision table](#ci-decision-table), including exact-SHA success, protected pending auto-merge, stale/missing/red CI, and human-waived cases.

Project-profile hooks in `delivery.project_profile` may specialize project gate
policy, labels, branch naming, CI jobs, domain docs, release/deploy policy,
manual validation, language families, and auxiliary indexes. They are routing
claims only: reviewers still enforce reviewed-SHA binding, exact-SHA CI,
explicit authority source, independent review, child-builder boundaries,
verifier read-only boundaries, and MCP-first transport correctness plus
help-first `glab` fallback correctness from Tier 1 or Tier 2 evidence.

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
| omitted not-applicable job (conditional required-job set) | Approval and authorized finish may proceed; the omitted job is not a missing/failed required job and does not block. | The pipeline is exact-SHA success at the reviewed SHA, every job that ran passed, and each absent job is `rules:`-omitted (absent, not `skipped`/`failed`) and declared not-applicable for this diff class (e.g. docs-only) by the target repo's check-gate doc / `project_profile` conditional required-job set. The required-job set is read from the target repo, never hard-coded in the skill. Fail-closed: a job absent for any reason *other* than a declared not-applicable rule still blocks (treat as `missing`); a `failed`/`canceled`/`pending` applicable required job still blocks (treat as the matching row); the exact-SHA success rule is unchanged. | `CI status / SHA: green (conditional set)`; `Action blocker: none`. |
| red/failed/canceled/skipped | No approval, merge, or queue action. | Pipeline for reviewed SHA is failed, red, canceled, skipped, or has required-job failure. If logs expose a fixable builder defect, record it as `MF-N`; approval still stays blocked until CI is fixed or human-waived. | `Review verdict: blocked` or `request-changes` with no approval; `Action blocker: stale-or-missing-ci`. |
| missing | No approval, merge, or queue action unless the human-waived row applies. | No decision-grade MR/branch pipeline is available for reviewed SHA, and project policy does not explicitly make CI N/A. | `Review verdict: blocked`; `Action blocker: stale-or-missing-ci`; `Next action: wait-ci` or `fix-blocker`. |
| stale | No approval, merge, or queue action unless the human-waived row applies. | Latest green/pending pipeline SHA differs from `Reviewed SHA`, or MR head changed after the reviewed pipeline. | `Review verdict: blocked`; `Action blocker: stale-or-missing-ci` or `changed-head-sha` when head changed. |
| human-waived | Approval and authorized finish may proceed only if the waiver explicitly covers the CI blocker. | Authorized human waiver source/comment is present in the MR, or the parent task quotes that human waiver source/comment; it names the CI state being waived and is recorded in the Review Report. Reviewer cannot self-waive CI. | `CI status / SHA: waived`; `Action blocker: none` for CI, while other guards still apply. |

### Open Question decision table

| OQ state | Review outcome | Required reviewer handling |
|---|---|---|
| answered from evidence | ok; pass allowed when every other guard passes. | Answer the `OQ-N` in `Open Questions Addressed`, cite evidence, and remove it from blockers. |
| builder evidence gap | request-changes. | Record an `MF-N` evidence request or targeted Must Fix that is revision-ready: exact locator, concrete problem, and bounded remedy direction. |
| human/product/security decision | blocked/no approval. | Use `Action blocker: human-decision-needed`, `Next action: human-escalation`, and do not approve until the decision source is recorded. Do not rewrite the missing decision as builder revision work. |
| non-blocking | `C-N` / follow-up with rationale; pass may still proceed when other guards pass. | Downgrade explicitly in `Open Questions Addressed`, explain why it is non-blocking, and link/create a follow-up when it must survive merge. |

## Parent-managed finish owner

`Finish owner: parent` means finish ownership, not merge authority. The reviewer still verifies approval/merge authority claims for routing and records the Review Report verdict/evidence, but the reviewer does not approve, direct merge, queue auto-merge, close, or clean up branches in parent-managed mode. A parent-managed pass handoff uses enum-safe values: `approval_action: "not-approved"`, `finish_action: "none"`, `action_blocker: "none"`, `next_action: "finish-by-authorized-actor"`, and `expected_next_actor: "parent"`. The parent/authorized finisher then performs any approval, direct merge, or auto-merge queue action only after fresh MR SHA, CI, authority/source, identity, and Mutation Guard checks pass.

## Default finish: queued auto-merge

On a `pass` verdict with verified merge authority, the default finish is to approve SHA-bound and then **queue auto-merge** (GitLab merge-when-pipeline-succeeds) via `gitlab` **Snippet: sha-bound-auto-merge-queue**, `--sha`-bound to the reviewed SHA. GitLab then completes the merge the instant the reviewed-SHA pipeline succeeds, and the reviewer/parent moves on immediately instead of block-watching the pipeline to completion and then direct-merging. This changes only *when the agent waits*, not *whether CI is a gate*. In `Finish owner: parent` mode the same queued auto-merge default is performed by the parent/authorized finisher after the durable pass Review Report, not by the reviewer.

The exact-SHA CI **floor is intact** and unchanged by this default: GitLab will not complete a queued merge until the reviewed-SHA pipeline succeeds, the target project's protected merge checks ("pipeline must succeed") still enforce green CI before merge, the `--sha` binding still pins the queued merge to the reviewed head, and any cfg-gated other-target / conditional required-job coverage from the [CI decision table](#ci-decision-table) is preserved. Queueing auto-merge is not a CI waiver and never substitutes for the reviewer's own exact-SHA CI verification.

**Fail-closed guard (queue only on non-terminal-or-green CI).** Queue auto-merge only when the reviewed-SHA pipeline is `pending`/`running`/`success`. If that pipeline is already `failed`/`canceled` (or red/skipped/missing/stale per the [CI decision table](#ci-decision-table)), that is still a block, not a queue: do not approve-and-queue. Route the red/failed/canceled/missing/stale CI state through the CI decision table (`Review verdict: blocked` or `request-changes`, `Action blocker: stale-or-missing-ci` or `changed-head-sha`) exactly as before. A `pending`/`running` reviewed-SHA pipeline is the normal queue case; `success` may queue or direct-merge per merge authority.

**Precondition.** The target project must have protected auto-merge enabled with "pipeline must succeed" required for merge; otherwise queued auto-merge cannot enforce the CI floor and the reviewer falls back to the CI decision table's pending/green rows. The known auto-merge-queue 405 fallback path routes through `gitlab` **Snippet: auto-merge-api-fallback**, preserving the same SHA/CI guards. If protected auto-merge is unavailable and CI is not yet exact-SHA green, do not direct-merge a pending pipeline; wait per the CI decision table or report the blocker.

For `approval-only` or `human release` merge authority, this default does not apply: stop after approval (or after reporting reviewed SHA/CI/blockers) without queueing or merging.

## GitLab transport reference

Reviewers load the small `gitlab` review cards before the full transport reference where possible:

- [`review-read`](../gitlab/reference/review-read.md) — preflight, issue/MR metadata, project binding reads, and artifact capture.
- [`ci`](../gitlab/reference/ci.md) — CI snapshots, exact-SHA CI waiting, and fail-closed CI verdict rules.
- [`review-actions`](../gitlab/reference/review-actions.md) — MR notes, issue-note target split, SHA guards, approval, merge, auto-merge queueing, approval confirmation, and authority-aware finish.

The cards carry snippet names, inputs/outputs, and fail-closed rules without copying raw command bodies. Full transport ownership still lives in the host project's issue-tracker guide or [`gitlab/SKILL.md`](../gitlab/SKILL.md): fall back to [`gitlab/SKILL.md`](../gitlab/SKILL.md) when a card is missing/ambiguous, MCP/fallback shape drifts, a needed command is not carded, non-review issue/MR operations are required, or helper behavior needs troubleshooting. This flow names snippets only where sequencing matters, and keeps SHA-bound approval, merge, auto-merge queueing, and approval confirmation choices visible at action points.


## Compact review cards

Use these cards as pointer-map checklists for common routes after the review mode
is known:

- [`single-mr-review-card.md`](reference/single-mr-review-card.md) — default one
  MR / one fresh reviewer session path.
- [`request-changes-rerun-card.md`](reference/request-changes-rerun-card.md) —
  fresh review round after a builder revision.
- [`finish-action-card.md`](reference/finish-action-card.md) — approval and
  finish-action sequencing after a pass-eligible report.
- [`blocked-review-routing-card.md`](reference/blocked-review-routing-card.md) —
  fail-closed blocker classification and parent routing.

The cards do not replace this file's Context Firewall, Review Context Capsule,
fail-closed coverage, CI decision table, Open Question decision table, authority
source precedence, project binding rules, final snapshot order, or SHA-guarded
action rules. Fall back to this full flow and `gitlab/SKILL.md` on
ambiguity, missing field, transport/help drift, authority uncertainty, SHA/CI
mismatch, cross-project binding, partial review, suspected secret exposure,
grouped action pressure, or any mutation action.

## Project binding

Every supplied MR URL, IID/ID, or branch name must be project-bound after
`gitlab` **Snippet: local-repo-preflight** and before MR pickup continues.
Before any MR comment, approval, merge, auto-merge, or close-equivalent action,
the reviewer must resolve one bound MR record and use it for comments,
approvals, merge, auto-merge, or close-equivalent actions.

Bound fields:

- `bound_host` — GitLab host from the supplied MR URL or preflight repo.
- `bound_project_path` — namespace/project path, for example `agents/skills`.
- `bound_repo_url` — explicit repo target accepted by `gitlab` snippet commands.
- `bound_mr_iid` — project-scoped MR IID.
- `bound_mr_url` — canonical full MR URL for reports and URL-based commands.
- `bound_source_branch` — source branch from decision-grade MR metadata.
- `bound_target_branch` — target branch from decision-grade MR metadata.
- `bound_current_sha` — current MR head SHA from decision-grade metadata.

Resolution rules:

1. For a full MR URL, parse host, project path, and IID from the URL, then
   re-read MR metadata through MCP using the bound project/MR, or through the full MR URL / `-R "$bound_repo_url"` when a guarded fallback path is in use.
2. For a bare IID/ID or branch, bind it to the preflight repo only, then
   re-read MR metadata through MCP with the bound project path, or with `-R "$bound_repo_url"` before trusting fallback output.
3. Compare `bound_host` and `bound_project_path` to the preflight repo. A mismatch blocks unless the user explicitly chooses the cross-repo review target; record that choice in the Review Report and final handoff before any GitLab mutation.
4. Transport rule: every decision-grade MR read and every GitLab mutation uses an
   explicit project/repo target or full MR URL. Prefer the bound MR IID plus
   `bound_project_path`/`bound_repo_url`; use the full MR URL when a URL was
   supplied or repo inference remains uncertain. Never use cwd-inferred bare IID
   action guidance for notes, approvals, merges, auto-merge queueing, or
   close-equivalent actions.

This binding rule also governs file-backed Review Reports and MR action-result
notes; use `gitlab` **Snippet: mr-note-create** MR notes binding
(canonical `safe_create_merge_request_note`) and keep issue-note commands out review-report posting paths. Large Review Report bodies MUST NOT be posted inline via MCP `safe_create_merge_request_note` strings.

## MR pickup

When the user supplies an MR ID/URL/branch, review it only after the
[Project binding](#project-binding) check succeeds. Otherwise pick one MR from
the **current GitLab project**. When the user supplies or requests multiple MRs,
do not treat one reviewer session as several independent review contexts: prefer
parent/harness fanout into one fresh reviewer session per MR/worktree, or enter
explicit serialized mode only after the set satisfies the shared
[Decoupling Contract](skill://start-review/docs/decoupling-contract.md):

1. Run `gitlab` **Snippet: local-repo-preflight** to confirm MCP/fallback project binding resolves to the cwd repo. If preflight fails, post/report `Review verdict: blocked` with `Action blocker: preflight-failure` when an MR context exists; otherwise stop and ask.
2. Bind supplied MR references to the preflight repo, or block on cross-repo mismatch until the user explicitly chooses the cross-repo review target.
3. If the current branch has an MR (use `gitlab` **Snippet: mr-pickup**), prefer it when the user says "this branch" or the branch is clearly under review.
4. Otherwise list open non-draft MRs with `gitlab` **Snippet: mr-pickup**. Narrow with MCP filters for label, assignee, reviewer, and target branch where available; guarded fallback may use the equivalent live-help-verified flags. Prefer MRs labeled with the project's ready-for-review equivalent, assigned/requested to `@me`, targeting main/default, with linked issues and passing or pending CI.
5. Deprioritize drafts, blocked MRs, MRs labeled with the project's revision/unblock/WIP equivalent, and obviously red-CI MRs unless the user asked for failure triage.
6. Inspect the selected candidate, or 3-5 candidates when selecting among MRs. For multiple requested MRs, inspect enough to validate coupling. Don't dump raw JSON; summarize MR ID, title, author, labels, CI state, linked issue, suitability, coupling risk.
7. If one MR is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user or parent to choose between separate reviewer-session fanout and explicit serialized mode.
8. For multiple supplied/requested MRs, prefer the builder's `Reviewer Lift > Decoupling proof` from each MR description and apply the [Decoupling Contract's reviewer consumer guidance](skill://start-review/docs/decoupling-contract.md#reviewer-consumer-guidance). If proof is absent, insufficient, inconsistent, or contradicted by evidence, collect changed paths with `gitlab` **Snippet: artifact-capture** (or the GitLab changes API) before declaring the set decoupled. Decoupling Contract proof is required before parent parallel fanout.

## Handoff integrity check

Before reading the full diff, validate the builder handoff:

- Project binding has a complete bound MR record (host, project path, repo URL, IID, source branch, target branch, and current SHA), and the bound MR URL/project is recorded for the Review Report and final handoff.
- Reviewer Lift exists and its rows match `start-build/templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema, and the Review Report derives the same rows. Treat the Reviewer Lift, Gate Receipt, and any shared `delivery.kind=gitlab-delivery` block as maps, not truth: every safety-critical field needs reviewer verification from Tier 1/Tier 2 evidence and source before it can support the verdict or an approval/finish action. Parent-owned Gate Receipt verification uses `../start-build/reference/parent-owned-gate.md`.
- `Finding bindings` is `none` or every short finding ID is bound to its originating stable report locator and exact reviewed SHA per [`reference/finding-identities.md`](reference/finding-identities.md). Validate non-`none` Lift bindings against all originating report files before relying on them for the ready/review path; missing, stale, ambiguous, or contradictory tuples fail closed.
- Review Context Capsule has repo, MR, authority, CI, scope, artifacts, and context-expansion rows with claim, verification, and source values, or the report explains why review blocked before completion.
- MR head SHA equals `Reviewed SHA`. If not, read the delta note/revision packet and re-diff the new commits before approval. If you cannot safely review the new head, report `Review verdict: blocked` with `Action blocker: changed-head-sha`.
- Gate owner is `builder` or `parent`, Gate coverage is `full-local`/`hybrid`/`ci-only` (never `parent-owned`), and Gate coverage rationale maps required CI jobs to local coverage plus unmapped CI-only jobs or `none`.
- CI pipeline evidence includes URL/ID, status, and commit SHA when available. Classify it with the [CI decision table](#ci-decision-table) before any approval or finish action; builder readiness does not bypass that table.
- Local gate is PASS, N/A with rationale, or `not-run` with a parent Gate Receipt bound to the reviewed SHA per `../start-build/reference/parent-owned-gate.md`; for `hybrid`/`ci-only`, exact-SHA CI success or an authorized waiver is required for uncovered required jobs before pass/approval/finish eligibility.
- Open Questions is either `none` or real `OQ-N` IDs. Ignore template placeholders only when obviously not filled, and classify real questions with the [Open Question decision table](#open-question-decision-table).
- `Acceptance surfaces` in the Reviewer Lift lists every named surface touched by the change, drawn from the project's `project_profile.acceptance_surfaces_ref` vocabulary; each declared surface must have `test`, `smoke`, `docs-read`, `ci`, or documented `N/A — <reason>` evidence. A declared surface without evidence and any named surface that is observably changed but undeclared are `MF-N` blockers before pass. When the project declares no `acceptance_surfaces_ref`, this row is fail-closed to `none` and you fall back to the `Touched safety surfaces` row; any non-empty surface value or an unresolvable surface ref is a schema defect `MF-N` blocker. Use the taxonomy in `start-build/templates/gitlab-delivery-schema.md#acceptance-surfaces-taxonomy`.
- Approval authority is `default-after-pass` with a stable repo policy source unless an explicit restriction source says otherwise. Verify it through [`../gitlab/reference/authority-verification.md`](../gitlab/reference/authority-verification.md). If approval is restricted, missing, contradictory, unverifiable, or ambiguous for the intended approval action, block approval and report `Action blocker: missing-authority`; do not infer merge authority from approval authority.
  Merge authority is explicit and treated as a quoted builder claim, not a grant. `Merge authority source` is mandatory and verifiable before merge, auto-merge, release, close, cleanup, or other finish actions; if merge authority or source is missing, contradictory, unverifiable, or ambiguous, block only the finish action and report `Action blocker: missing-authority`. Explicit `approval-only` is valid when its source verifies it and means approval may proceed after normal guards, but merge/auto-merge may not. Authority Verification names whether the actor can proceed, must hand off, or must ask a human.
- Post-ready pushes include an old SHA → new SHA delta comment; substantive deltas should have a Revision Packet.
- Every substantive Revision Packet repeats the originating `(Report locator, Reviewed SHA, Finding ID)` for each `MF-N`/`SF-N`/`C-N` it addresses and passes `validate-finding-bindings.mjs` before publication. A bare reused short ID is not revision evidence.

## Multiple MR worktree mode

Use only when the user supplies multiple MRs, asks for multiple reviews, or asks to review the next N ready MRs. Default/preferred behavior remains one MR per fresh reviewer session. A single reviewer session cannot provide separate LLM contexts for multiple MRs.

1. Resolve and decouple candidates first using [MR pickup](#mr-pickup): candidate resolution (collect at least IID, title, source/target branch, head SHA, author, labels, CI state, linked issue, and changed paths) and the `Reviewer Lift > Decoupling proof` / [Decoupling Contract](skill://start-review/docs/decoupling-contract.md#reviewer-consumer-guidance) check both live there. If coupling is unclear after the contract check, review serially in the safest order or ask the user to choose. Never parallelize coupled work to save time, and never group approvals or finish actions for coupled MRs.
2. Parallel multiple-MR review requires parent/harness-provided separate sessions and worktrees: one reviewer session per MR/worktree. Use the original checkout as a coordinator for GitLab queries only. Create one review worktree per MR when local checkout/tests are needed. Do not use shared `FETCH_HEAD` in parallel review mode; fetch each MR into its own temp ref:
   - `git fetch origin +refs/merge-requests/<iid>/head:refs/tmp/review/mr-<iid>`
   - `git worktree add --detach <path> refs/tmp/review/mr-<iid>`
   - `git -C <path> rev-parse HEAD` must equal MR metadata `sha`; if not, refresh metadata and stop if still mismatched.
3. If a parent/harness has already provided parallel reviewer sessions and worktrees, keep one reviewer session per MR/worktree. If you are running inside a reviewer child session, review only the assigned MR/worktree and do not launch sibling reviewers. Review independence requires separate LLM/session context plus separate checkout for local execution.
4. Explicit serialized mode does not batch decisions, comments, actions: finish one MR's MCP-safe, read-back-verified Review Report, `Review verdict`, reviewed SHA, action result, final handoff before starting next MR.
5. Produce one Review Report, one `Review verdict`, and one reviewed SHA per MR. Do not group multiple MRs into one GitLab comment, approval, request-changes, reject, or blocked action.
6. Approval/merge sequence per MR:
   - re-run `gitlab` **Snippet: sha-guard** immediately before any approval, merge, or auto-merge action; the decision point must visibly bind the reviewed head and project by resolving the current SHA from `bound_mr_iid` plus `bound_repo_url` (or `bound_mr_url`) and comparing it to `reviewed_sha`;
   - approve with `gitlab` **Snippet: sha-bound-approval** only when approval is authorized, using the bound MR IID plus `-R "$bound_repo_url"` or the full `bound_mr_url`;
   - confirm approval with `gitlab` **Snippet: approval-confirmation** when approval status must be verified;
   - before direct merge, re-run a fresh SHA guard immediately before direct merge, then use `gitlab` **Snippet: sha-bound-merge** only when direct merge is authorized;
   - before queueing auto-merge, re-run a fresh SHA guard immediately before the auto-merge queue action, then use `gitlab` **Snippet: sha-bound-auto-merge-queue** only when queueing auto-merge is authorized;
   - choose one action at each authorization point; never run a combined approval/merge block or paste multiple action snippets as one executable sequence;
   - if SHA-bound approval/merge flags are unavailable or unsupported, report `Review verdict: blocked` with `Action blocker: sha-bound-action-unsupported` rather than taking an unpinned action;
   - after merging one MR, re-check remaining MRs' CI and `detailed_merge_status`; if one becomes conflicted/stale, stop that MR and report the blocker instead of forcing.
7. Remove a review worktree only when no local evidence/artifacts are needed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Then delete the temp ref if no other review uses it: `git update-ref -d refs/tmp/review/mr-<iid>`.

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
2. Read the linked issue and MR description before the diff using `gitlab` **Snippet: issue-pickup** and **Snippet: mr-pickup** with the bound MR URL or explicit repo target. Apply the [Context Firewall](#context-firewall) and [context tiers](#context-tiers): Tier 1 reads are required; Tier 2 reads need concrete risk triggers; Tier 3 broad context is forbidden by default.
3. **Lift the builder's `Reviewer Lift` block as a map, not truth.** Copy each field from `start-build/templates/reviewer-lift-schema.md` into the matching Review Report fields, then verify safety-critical fields from independent sources before relying on them. If a shared `delivery.kind=gitlab-delivery` block exists, use it only as an index into Tier 1/Tier 2 evidence and do not treat its compact fields as proof. If older MRs lack `Approval authority`, apply the default approval policy only when a stable repo/rulebook source exists and no explicit restriction is present; do not infer merge authority. Missing, contradictory, or ambiguous `Merge authority` or `Merge authority source` blocks merge/auto-merge/release/close/cleanup until the Review Packet, parent task prompt, human MR comment URL, rulebook path+section, or project default source resolves it.
4. Confirm the MR `sha` from `gitlab` **Snippet: mr-pickup** using the bound MR URL or `-R "$bound_repo_url"` equals the lifted `Reviewed SHA`. If they differ, the builder pushed after marking ready; read the delta note / `Delta since last ready push`, treat the new commits as part of this review, and either re-diff them or request a Revision Packet referencing them before approval. If safe re-review is not possible, report `Action blocker: changed-head-sha`.
5. Check labels/status, changed paths, and declared safety-critical surfaces without changing approval eligibility solely due to label absence/mismatch.
6. **Sweep `Reviewer Focus` first** — read those areas hardest before walking the full diff with `gitlab` **Snippet: artifact-capture** as needed. Note your findings in the Review Report's `Reviewer Focus Sweep` section even when nothing is wrong.
7. Walk the review categories: scope match, strategy/safety invariants, architecture boundaries, correctness (edges, recovery, exact-decimal math, concurrency, timestamps), tests/evidence, external-API safety (adapters/quirks/redaction), state/DB/migrations (typed models, atomic writes, append-only migrations), observability/ops (metrics, health, runbooks), security/credentials, the fail-closed partial-review/secret-exposure rules, and the bounded structural maintainability sweep. For behavior-touching MRs, apply `tdd` test-quality principles when judging evidence.
8. Fill the [Review Context Capsule](#review-context-capsule) with claim, reviewer verification, and source entries for repo, MR, authority, CI, scope, artifacts, and context expansion. Keep parent/builder reasoning as a claim only; cite Tier 1/Tier 2 evidence for verification.
9. Verify CI status against the lifted `CI pipeline` value with `gitlab` **Snippet: ci-decision-snapshot**, then classify it with the [CI decision table](#ci-decision-table). Verify Gate owner/coverage/rationale against the project gate policy and required CI mapping; `parent-owned` as coverage is invalid. If the lifted `Local gate` says `not-run` because `local_gate_owner: parent`, locate the Gate Receipt MR comment and verify its MR IID, issue IID, checkout path, checkout SHA, status before/after, exact command, result, summary, preflight checks, evidence, and optional observation timestamp before treating the local gate as satisfied.
10. When local execution is needed because behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution, enter **Single MR checkout mode** first for one MR (or the existing multiple-MR worktree path for multiple MRs), then run targeted tests only from the verified exact-SHA checkout. Do **not** run mutating commands.
11. **Address every `OQ-N` from the MR description in the report's `Open Questions Addressed` section.** Classify each question with the [Open Question decision table](#open-question-decision-table) before choosing the review verdict or action fields.
12. Post inline comments for specific lines where useful.
13. **Draft Review Report before final guards.** Normative report/action order: draft Review Report -> final MR/CI/authority snapshot -> convert approval or finish action fields blocked when guards fail -> post Review Report through MCP-native `gitlab` **Snippet: mr-note-create** (`safe_create_merge_request_note`) -> read back created note and verify body matches source report file/content -> SHA guard before approval -> authorized action -> optional action-result note/final handoff. Fill **Reviewer** metadata `@reviewer — <model-id>` (e.g. `@reviewer — claude-opus-4-7`); do not add separate model-only row; if harness doesn't expose model id, omit instead guessing. In draft, action fields describe intended action approval/merge/auto-merge will happen after posting; must not claim completed GitLab side effects before effects verified.
   Assign one stable Report locator before publication, add every real finding to the marked identity table with the exact reviewed SHA, and run `node start-review/scripts/validate-finding-bindings.mjs --report <report.md>` per [`reference/finding-identities.md`](reference/finding-identities.md) before the final posting guard.
14. **Take final MR/CI/authority snapshot before posting.** Re-read bound MR metadata, current head SHA, pipeline SHA/status, `detailed_merge_status`, `Approval authority`, `Approval authority source`, explicit `Merge authority`, and verifiable `Merge authority source` using bound MR URL or explicit repo target. If final guard fails review or approval path, convert drafted report to `Review verdict: blocked`, set appropriate `Action blocker`, set approval/finish actions to blocked or none, and only then post the report. If only merge/finish authority is missing or restricted, a pass report may still record an intended approval under default approval policy while setting finish action to blocked or none. If `Finish owner: parent`, keep the pass verdict path non-mutating: `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, `Next action: finish-by-authorized-actor`.
15. **Post verify one durable Review Report.** Post one top-level **Review Report** comment per MR **plain, non-resolvable note** using canonical MCP-native `gitlab` **Snippet: mr-note-create** (`safe_create_merge_request_note`) against the bound MR URL / explicit repo target. Validate the full report body with `validate_gitlab_text` or the safe note tool's embedded Safe GitLab Text validation before posting. Large Review Report bodies MUST NOT use unsafe raw inline `create_merge_request_note` strings. Do **not** post report as a resolvable discussion thread; an informational report thread left open can block merge. After posting, read back the created note and verify the note body/content matches the source report before treating it as durable. Placeholder, partial, literal-expansion, or body-mismatch notes fail closed: repost through MCP-safe note posting or record a transport blocker. Fill `Review verdict`, `Approval authority`, `Approval authority source`, `Approval action`, `Merge authority`, `Merge authority source`, `Finish action`, `Action blocker`, and `Next action` before posting, using intended-action wording before side effects and completed-action wording only after side effects are verified. Redact suspected secret findings before posting.
   The finding-binding validator and Safe GitLab Text validation are separate pre-publication checks; both must pass before the single note mutation.
   After posting, read back the created MR note through GitLab MR notes/discussions and verify its body matches the source report file/content before treating the Review Report as durable/posted. Placeholder, partial, literal-expansion, or body-mismatch notes fail closed: do not accept them as durable Review Reports; repost through the file-backed path or record a transport blocker. Fill `Review verdict`, `Approval authority`, `Approval authority source`, `Approval action`, `Merge authority`, `Merge authority source`, `Finish action`, `Action blocker`, and `Next action` before posting, using intended-action wording for post-report actions and completed-action wording only for side effects already verified. Redact suspected secret findings before posting; use `[REDACTED]`, path/line or artifact locator, and `secret-exposure-suspected` blocker token instead of copying sensitive values.
16. **Re-run `gitlab` Snippet: sha-guard after durable-report verification and immediately before approving outside parent-managed mode.** If `Finish owner: parent`, skip reviewer approval entirely and route the durable pass report to the parent/authorized finisher. Otherwise The action point must visibly resolve current SHA from `bound_mr_iid` plus `bound_repo_url` and compare it to `reviewed_sha`; use full `bound_mr_url` instead when it is the safer locator. Approval is authorized only by verified approval policy (`default-after-pass`) unless an explicit restriction source blocks it, plus normal review, CI/OQ/local-gate, coverage, SHA guards. If head SHA changes after report posting but before action, skip approval, merge, and auto-merge; optional action-result note or final handoff reports stale SHA, current SHA, reviewed SHA, bound MR URL/project, `Action blocker: changed-head-sha`, and `Next action: rerun-review`. Never approve a SHA you have not read.
17. Apply posted Review Report outcome. `pass` may proceed to a separate approval action after durable-report verification and post-report SHA guard when approval authority is not restricted. In `Finish owner: parent` mode, pass does **not** proceed to reviewer approval or finish; it routes to parent/authorized finisher with `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, and `Next action: finish-by-authorized-actor`. `request-changes` keeps MR open for builder revision. `reject` is non-mutating by default: do not close MR unless explicit human/project close authority says to close it. `blocked` takes no approval, merge, auto-merge, or close action; route by `Action blocker` and `Next action`. Permission failures during approval/merge map `Action blocker: permission-failure`; record failed action in final handoff and, when useful, durable action-result note.
18. **Guard before finish action outside parent-managed mode.** If `Finish owner: parent`, do not approve, merge, or queue auto-merge; final handoff routes `finish-by-authorized-actor` to the parent. Otherwise, **Queued auto-merge default finish action** on `pass` verdict with verified merge authority (see [Default finish: queued auto-merge](#default-finish-queued-auto-merge)): approve SHA-bound, queue auto-merge so GitLab completes merge when the reviewed-SHA pipeline succeeds, instead of block-watching CI completion before direct merge. Before queueing auto-merge, re-run fresh SHA guard immediately before auto-merge queue action, use `gitlab` **Snippet: sha-bound-auto-merge-queue** only when merge authority permits queueing, and target bound MR URL or explicit repo target. Use direct merge only when CI is already exact-SHA green (or human-waived) and merge authority permits direct merge: re-run fresh SHA guard immediately before direct merge, then use `gitlab` **Snippet: sha-bound-merge** against bound MR URL or explicit repo target. If head changed, skip finish action and report `changed-head-sha` in an action-result note/final handoff rather than acting on stale report.
19. **Final reviewer handoff.** After durable Review Report verification and any authorized approval, merge, or auto-merge action attempt, final response MUST include the machine-readable block from `templates/reviewer-final-handoff.md` when the template is available; if the template is unavailable, say so and still provide the same fields in prose. Fill it with the same verdict/action vocabulary as Review Report: bound MR URL/project, `review_verdict` (`pass / request-changes / reject / blocked`), `reviewed_sha`, pipeline status/SHA, local checks, `MF-N` / `SF-N` / `C-N` finding IDs, Open Question handling, `approval_authority`, `approval_authority_source`, `merge_authority`, `merge_authority_source`, `approval_action`, `finish_action`, `action_blocker`, `next_action`, `report_url` or `N/A`. Keep GitLab Review Report comment the durable review record; final handoff is parseable routing context, not a substitute report.
   The handoff exposes the same stable report locator and exact reviewed SHA, and every finding item repeats that locator/SHA beside its short ID so parent routing never relies on a bare `MF-N`/`SF-N`/`C-N`.

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

See [templates/filling-guide.md §review-report.md](templates/filling-guide.md#review-reportmd) for canonical list report sections per-section guidance. Review Reports are file-backed MR notes only: use canonical `gitlab` **Snippet: mr-note-create** / `safe_create_merge_request_note`, never bypass the safe-note contract with ad hoc inline note strings, read back the created note and verify its body matches source report file/content before it counts posted, and fail closed on placeholder, partial, literal-expansion, or body-mismatch notes. Every Must Fix names path + line/range + concrete problem + bounded remedy direction. Use inline comments for line-anchored findings reference Must Fix IDs so revision commits can cite them. When human/product/security choice actual blocker, keep it in blocked routing (`human-decision-needed`) instead inventing pseudo-fix builder.

Each report chooses one stable Report locator before publication, exposes it with the exact `Reviewed SHA`, and lists every short finding ID in the canonical tuple table from [`reference/finding-identities.md`](reference/finding-identities.md). The pure-local validator must pass before the Review Report note is posted. Short IDs remain readable and may be reused by later reports only because the full tuple is distinct.

## Decisions

- **Pass** — scope matches, no Must Fix remains (including no blocker-level structural maintainability regression), every behavior-affecting changed surface was inspected, every `OQ-N` is classified as pass-eligible by the [Open Question decision table](#open-question-decision-table), tests/evidence are adequate, bound MR project is verified against the preflight repo or explicit cross-repo target, head SHA equals the SHA you reviewed, `Approval authority` is `default-after-pass` with a verified stable policy source or an explicit verified restriction is not blocking, and CI is pass-eligible by the [CI decision table](#ci-decision-table). Re-run `gitlab` **Snippet: sha-guard** using an explicit repo target or full MR URL, then choose the authorized action against that same bound target: SHA-bound approval when approval authority allows it; then, when separate `Merge authority` and `Merge authority source` allow finish, **queue auto-merge as the default finish** per [Default finish: queued auto-merge](#default-finish-queued-auto-merge) (approve, then `sha-bound-auto-merge-queue`), or direct merge only when CI is already exact-SHA green/waived and merge authority permits direct merge. Missing merge authority/source blocks finish, not the review judgment or default approval by itself.
- **Request changes** — fixable Must Fix items and the approach is sound. Those Must Fix items must already be revision-ready (exact locator, concrete problem, bounded remedy direction). Apply the project's revision label if one exists; keep the MR open.
- **Reject** — premise/architecture/scope is wrong, or a safety boundary is weakened beyond what the user/project accepts. Post the Review Report with the reject verdict, explain why and what would need to change before a new or continued MR can proceed, then stop and escalate to the parent/human. Leave the MR open by default; closing an MR requires explicit human/project close authority. Reject requires human follow-up; don't auto-spawn a revision.
- **Blocked** — guard/tool/authority/security state prevents a safe approval or finish without judging the code as fixable or invalid. Use `Approval action: blocked` or `not-approved`, `Finish action: none` or `blocked`, and one `Action blocker`: `missing-authority`, `stale-or-missing-ci`, `changed-head-sha`, `merge-conflict`, `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`, `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or `other`. Parent orchestrators route blocked outcomes to authority/CI/tooling/security/human-decision handling, not to builder code revision unless the blocker itself names builder work.

## After review

- **Reject / Blocked / Pass:** post the Review Report, then apply the per-verdict post-action handling already specified in [Decisions](#decisions) — reject stops/escalates to parent/human without closing the MR absent explicit close authority; blocked takes no approval/merge/close action and routes by `Action blocker` and `Next action`; pass records its own reviewed SHA, separate Approval action and Finish action, and final handoff.
- **Request changes:** Build agent pushes commits and replies to threads; reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution.
- **Stuck Packet:** post `templates/unblock-response.md` as an MR comment with `gitlab` **Snippet: mr-note-create**, give short direction, and remove the project's unblock label when one exists and work resumes.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Reviewer template filling guide](templates/filling-guide.md)
- [Shared ADR filling guide](shared-templates/filling-guide.md)

Safety-critical filling rules are stated in full earlier in this flow; do not restate them here. Use these pointers:

- Context Firewall, context tiers, and "parent/builder reasoning is not evidence" (same-session builder/parent/planner/reviser review is advisory only): [Context Firewall](#context-firewall).
- Reviewer Lift as a map (not truth) plus the safety-critical verification/source requirement and `Reviewed SHA` head match: [Review Context Capsule](#review-context-capsule) and [Handoff integrity check](#handoff-integrity-check).
- CI, Open Question, and stable `OQ-N` classification: [CI and Open Question decision tables](#ci-and-open-question-decision-tables).
- Secret/credential handling, redaction, and `secret-exposure-suspected`: [Fail-closed review coverage](#fail-closed-review-coverage).
- Stable review item tuples (`Report locator`, exact `Reviewed SHA`, and human-readable `MF-N`/`SF-N`/`C-N`), follow-up issues for surviving non-blocking findings, and brief-quality defects: [Finding identities](reference/finding-identities.md), [Review Report expectations](#review-report-expectations), and the [Reviewer template filling guide](templates/filling-guide.md).
