---
name: start-build
description: >-
  Implement GitLab issues: pick up scoped issues, TDD red-green-refactor slices,
  open Draft MRs with Review Packets, handle review revisions. Trigger: start a
  build, pick up/implement issue(s), fix bugs, add features, open MRs.
---

# Start Build

## Purpose

Implement scoped GitLab issues and produce reviewable changes: code, tests, docs, migrations, MRs. Operate as a **very senior software developer**: evidence-first, narrow-context, exhaustive in rigor, explicit about tradeoffs, and unwilling to invent facts. Go above and beyond on correctness — tests, edge cases, failure modes, and regression evidence for the behavior this issue changes — but never by widening scope: go deep on the assigned issue, not wide. Scale ceremony to risk and blast radius per the shared [Effort Scaling](docs/effort-scaling.md) tiers; the safety floors there (mandatory review gate, TDD, SHA/CI/authority guards) never scale away. Single-issue is the default. Multiple issues are allowed only when they satisfy the shared [Decoupling Contract](docs/decoupling-contract.md); each gets its own branch, worktree, MR, check evidence, and Review Packet. Treat every project as safety-critical unless its rulebook says otherwise.

This skill is language- and domain-agnostic; domain-specific safety terms below are examples to map onto the host project's equivalent surfaces. **Load the host project's rulebook index first** (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or an equivalent entry point). Load architecture docs, ADRs, domain docs, and `CONTEXT.md` only when evidence makes them relevant: issue links, rulebook references, changed paths, imports/callers, tests, safety invariants, failing checks, or explicit user/parent prompt. Project rules override this skill where stricter. Handoff lives in **GitLab**: tasks are issues, proposals are MRs, review happens in MR discussions. Fill templates into MR descriptions/comments; never commit `.reviews/` artifacts.

## Invocation modes

- **Standalone `/start-build` mode** — the builder owns the mandatory review gate: after marking the MR ready, spawn a fresh reviewer, drive the review loop, post the Review Gate Summary, and never self-approve or self-merge.
- **Child `mr-builder` mode** — the child builder builds, opens/updates the MR, and stops at final handoff. It marks ready only when it owns the local gate; in parent-owned gate mode it records the not-run contract and leaves the MR Draft for the parent Gate Receipt / ready transition. The parent orchestrator owns the mandatory review gate and merge; the child builder does not spawn a reviewer unless the parent explicitly instructs it to.

Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR. Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger. Exception categories require MR rationale and must not allow fake tests or meaningless checks. Issue-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice. Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions. Keep context as narrow as possible: issue, rulebook, affected docs/source/tests, and evidence-linked references first; expand only when a concrete dependency, test, or safety invariant requires it.

## Mode routing context read matrix

Use this first-screen matrix before expanding context. Load the required files/sections for the active mode, add optional context only when evidence requires it, and stop before avoid sections unless the caller changes scope.

| Mode | Required files / sections | Optional expansion | Stop / avoid |
|---|---|---|---|
| Parent orchestrator | Project rulebook index; [reference/parent-orchestrator.md](reference/parent-orchestrator.md); [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe) compatibility anchor; [reference/multiple-worktrees.md](reference/multiple-worktrees.md); [Decoupling Contract](docs/decoupling-contract.md) when multiple issues are in scope. | [issue-delivery-loop/SKILL.md](../issue-delivery-loop/SKILL.md) for batch loops; evidence-triggered architecture docs, ADRs, domain docs, or `CONTEXT.md`; [BUILD-FLOW.md §Post-merge verifier recipe](BUILD-FLOW.md#post-merge-verifier-recipe) only after authorized finish. | Child implementation details after launch, reviewer internals beyond minimal launch prompt, and direct approve/merge/auto-merge commands unless authority and role allow them. |
| Standalone builder | Project rulebook index; [SAFETY.md](SAFETY.md); [reference/implementation-flow.md](reference/implementation-flow.md); [reference/standalone-gate.md](reference/standalone-gate.md); review packet template. | `tdd` skill for behavior work; evidence-triggered architecture docs, ADRs, domain docs, or `CONTEXT.md`; [reference/context-and-planning.md](reference/context-and-planning.md); [BUILD-FLOW.md §Mandatory review gate](BUILD-FLOW.md#mandatory-review-gate) compatibility anchor. | Parent-orchestrator recipe unless coordinating child agents; post-merge verification unless separately assigned; self-approval, self-merge, or fallback finish actions. |
| Child `mr-builder` | Project rulebook index; [SAFETY.md](SAFETY.md); [reference/child-builder.md](reference/child-builder.md); [BUILD-FLOW.md §Child `mr-builder` mode](BUILD-FLOW.md#child-mr-builder-mode) compatibility anchor; [templates/reviewer-lift-schema.md](templates/reviewer-lift-schema.md); [templates/builder-final-handoff.md](templates/builder-final-handoff.md). | `tdd` skill for behavior work; [reference/context-and-planning.md](reference/context-and-planning.md) for Discovery Budget/check gate; [reference/implementation-flow.md](reference/implementation-flow.md) only when compact child flow is insufficient; affected issue-linked docs/tests only. | Avoid [reference/parent-orchestrator.md](reference/parent-orchestrator.md), [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe), [reference/standalone-gate.md#reviewer-launch-protocol](reference/standalone-gate.md#reviewer-launch-protocol), merge/finish action sections such as [`gitlab-local` finish guidance](../gitlab-local/SKILL.md#snippet-finish-mr-authority-aware), and [BUILD-FLOW.md §Post-merge verifier recipe](BUILD-FLOW.md#post-merge-verifier-recipe) unless parent changes role scope. |
| Revision builder | Review findings and reviewed SHA; [reference/implementation-flow.md](reference/implementation-flow.md) revision/post-ready rules; [templates/revision-packet.md](templates/revision-packet.md); [templates/reviewer-lift-schema.md](templates/reviewer-lift-schema.md). | Targeted tests for each finding; full gate evidence; `tdd` skill when revision touches behavior; [BUILD-FLOW.md §Implementation flow](BUILD-FLOW.md#implementation-flow) compatibility anchor. | Reusing stale review evidence, silently pushing after ready, resolving reviewer threads unless project policy allows it, or spawning a reviewer in child mode. |
| Docs-only/config-only builder | Project rulebook index; affected docs/config; [templates/review-packet-compact.md](templates/review-packet-compact.md); [reference/context-and-planning.md#compact-packet-eligibility](reference/context-and-planning.md#compact-packet-eligibility); repo [Check Gate](docs/agents/check-gate.md). | Markdown/link checks; [reference/context-and-planning.md#check-gate-discovery](reference/context-and-planning.md#check-gate-discovery); evidence-triggered docs ownership map; [BUILD-FLOW.md §Compact packet eligibility](BUILD-FLOW.md#compact-packet-eligibility) compatibility anchor. | Skip `tdd` and record `TDD: N/A` unless behavior becomes touched; avoid runtime/operator/safety behavior sections when no such surface changes. |
| Multi-issue coordinator | Supplied issues; [reference/multiple-worktrees.md](reference/multiple-worktrees.md); [BUILD-FLOW.md §Multiple issue worktree mode](BUILD-FLOW.md#multiple-issue-worktree-mode) compatibility anchor; [Decoupling Contract](docs/decoupling-contract.md); source branch/worktree plan. | [reference/parent-orchestrator.md](reference/parent-orchestrator.md) when delegating; [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe) compatibility anchor. | Parallel work when any decoupling item is false/unknown; coding in the coordinator checkout; combining Review Packets or shared run artifacts across issues. |

## Compact mode cards

Use the compact cards as pointer-map checklists only after the active mode is known: [`reference/child-builder-card.md`](reference/child-builder-card.md), [`reference/parent-owned-gate-card.md`](reference/parent-owned-gate-card.md), [`reference/revision-card.md`](reference/revision-card.md), and [`reference/parent-orchestrator-card.md`](reference/parent-orchestrator-card.md). Canonical policy stays in the mode reference docs, `SAFETY.md`, templates, and `/gitlab-local`; fall back there on ambiguity, missing field, CLI/help drift, authority uncertainty, SHA/CI mismatch, cross-project binding, partial review, or any mutation action.

## Quick start

1. Load `gitlab-local` and run **Snippet: local-repo-preflight** to verify `glab`/`jq` are installed, authenticated, and the cwd is the intended GitLab repo.
2. Read [SAFETY.md](SAFETY.md) before changing files.
3. Read the [BUILD-FLOW.md](BUILD-FLOW.md) router plus the active mode-specific reference doc from the matrix before selecting issue(s), creating/updating MR(s), commenting, or marking ready. Child builders use [reference/child-builder.md](reference/child-builder.md) instead of parent/standalone gate detail.
4. Resolve the issue(s): supplied IDs/URLs, or pick one (or a decoupled set) from the current project.
5. Start clean: `git status --porcelain` empty, `git fetch origin`, default branch detected, `origin/<default>` current. If dirty/stale, stop and ask.
6. Single issue → branch from latest default in cwd. Multiple issues → one sibling worktree per issue from `origin/<default>`; never share a checkout.
7. Open a Draft MR early per issue once the source branch exists remotely with `gitlab-local` **Snippet: draft-mr-create**, `Closes #<id>`, and the appropriate Review Packet template. Use **Snippet: mr-description-update** for later description / Reviewer Lift refreshes. Fill the **Reviewer Lift** block using `templates/reviewer-lift-schema.md` so the reviewer can copy structured values directly into their report, and record loaded context sources plus relevance in the Build Plan Packet or Review Packet. Quote `Approval authority` as `default-after-pass` with source unless an explicit restriction applies. Quote `Merge authority` as a finish-authority claim and fill `Merge authority source`; the builder cannot grant approval, merge, or auto-merge authority.
8. Apply the behavior-touching implementation TDD policy above. For docs/config-only, state `TDD: N/A` with rationale in the MR.
9. Run the project's full check gate per MR/worktree, or explain why only CI can provide it. In parent-owned gate mode, do not claim the final gate result; record `local_gate_owner: parent`, builder gate status `not-run`, `not_run_reason: parent-owned`, and `ready_transition_owner: parent`. Update the MR description with `gitlab-local` **Snippet: mr-description-update** (including every field from the Reviewer Lift schema, especially `Approval authority source` and `Merge authority source`) and mark ready with **Snippet: draft-mr-mark-ready** only when this builder owns the local gate and it is green.
10. **Review-gate handoff** — after ready (or after the Draft candidate handoff in parent-owned gate mode), follow the invocation mode above: standalone builders spawn a fresh reviewer per the [standalone review gate](reference/standalone-gate.md) protocol (compatibility anchor: [Mandatory review gate](BUILD-FLOW.md#mandatory-review-gate)); child `mr-builder` agents stop at final handoff for the parent orchestrator.

## Issue pickup summary

When the user supplies issue IDs/URLs, use them if suitable. Otherwise pick from the **current GitLab project**: prefer open issues assigned to `@me` or unassigned, ready/triaged, clear, unblocked, and fit one MR. For multiple issues, keep only a set that satisfies the shared [Decoupling Contract](docs/decoupling-contract.md). Deprioritize blocked issues, issues with the project's information-needed or human-decision equivalent, in-progress/WIP items, and confidential/security-sensitive issues unless explicitly requested. See [reference/issue-pickup.md](reference/issue-pickup.md) for the full procedure using `gitlab-local` snippet names; [BUILD-FLOW.md §Issue pickup](BUILD-FLOW.md#issue-pickup) remains the compatibility anchor.

## Essential safety summary

- No live product/runtime/operator external mutations during development/review unless the human explicitly requested an operator action. GitLab issue/MR actions prescribed by this workflow are allowed.
- Never touch, print, summarize, commit, or paste credentials or sensitive payloads.
- Don't weaken safety gates, locks, sequencing, immutable baselines, schemas, migrations, or deploy topology casually.
- Use project adapters for external APIs; new raw HTTP/SDK/CLI calls require ADR-level justification.
- Every behavior change needs meaningful tests and regression evidence.
- Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR; do not fake tests.
- Keep scope tight; file follow-up GitLab issues instead of drive-by refactors.

See [SAFETY.md](SAFETY.md) for non-negotiables, refactor rules, quality rules, escalation, and done criteria.

## Templates

- `templates/reviewer-lift-schema.md` — canonical Reviewer Lift field names, order, and required semantics.
- `templates/gitlab-delivery-schema.md` — canonical shared GitLab `delivery.kind=gitlab-delivery` block, `project_profile` extension hooks, evidence taxonomy, action/authority enums, and generated-copy drift contract.
- `templates/gitlab-delivery-schema.md` also defines `gate_receipt.kind=gate-receipt` for parent-owned local gate evidence before ready-marking. Project-profile hooks may specialize gate policy, labels, branch naming, CI jobs, domain docs, release/deploy policy, manual validation, language families, and auxiliary indexes, but must not weaken reviewed-SHA binding, exact-SHA CI, explicit authority source, independent review, the child-builder boundary, the verifier read-only boundary, or help-first `glab` correctness.
- `templates/builder-final-handoff.md` — machine-readable child-builder final response block for parent-orchestrator parsing.
- `templates/review-packet.md` — full MR description.
- `templates/review-packet-compact.md` — compact MR description for simple changes.
- `templates/build-plan-packet.md` — pre-edit discovery packet for issue, intended behavior, affected surfaces, test plan, risk, and non-goals.
- `templates/revision-packet.md` — comment for responding to review.
- `templates/stuck-packet.md` — comment when blocked >2h.
- `templates/filling-guide.md` — section-by-section filling instructions for builder templates.
- `templates/adr.md` — committed under `docs/adr/NNN-kebab-title.md` via its own MR; see shared `shared-templates/filling-guide.md`.

## Done

See [SAFETY.md §Done criteria](SAFETY.md#done-criteria) for the canonical completion checklist. That checklist is mode-specific: a child `mr-builder` is done at the builder-ready tier (MR ready + handoff), while review-gate-complete, finish-merge, and post-merge-verified belong to later, authority-scoped roles. Match the tier to your active mode in the routing matrix above.
