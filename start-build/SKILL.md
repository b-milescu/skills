---
name: start-build
description: >-
  Implement GitLab issues: pick up scoped issues, TDD red-green-refactor slices,
  open Draft MRs with Review Packets, handle review revisions. Trigger: start a
  build, pick up/implement issue(s), fix bugs, add features, open MRs.
---

# Start Build

## Purpose

Implement scoped GitLab issues and produce reviewable changes: code, tests, docs, migrations, MRs. Operate as a **very senior software developer**: evidence-first, narrow-context, explicit about tradeoffs, and unwilling to invent facts. Single-issue is the default. Multiple issues are allowed only when they satisfy the shared [Decoupling Contract](../docs/decoupling-contract.md); each gets its own branch, worktree, MR, check evidence, and Review Packet. Treat every project as safety-critical unless its rulebook says otherwise.

This skill is language- and domain-agnostic; domain-specific safety terms below are examples to map onto the host project's equivalent surfaces. **Load the host project's rulebook first** (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, architecture docs, ADRs). Project rules override this skill where stricter. Handoff lives in **GitLab**: tasks are issues, proposals are MRs, review happens in MR discussions. Fill templates into MR descriptions/comments; never commit `.reviews/` artifacts.

## Invocation modes

- **Standalone `/start-build` mode** — the builder owns the mandatory review gate: after marking the MR ready, spawn a fresh reviewer, drive the review loop, post the Review Gate Summary, and never self-approve or self-merge.
- **Child `mr-builder` mode** — the child builder builds, opens/updates the MR, marks it ready, and stops at final handoff. The parent orchestrator owns the mandatory review gate and merge; the child builder does not spawn a reviewer unless the parent explicitly instructs it to.

For runtime/operator/safety behavior changes, load and follow the `tdd` skill. If TDD is not applicable (docs-only, mechanical rename, generated update, urgent hotfix), say why in the MR. Keep context as narrow as possible: issue, rulebook, affected docs/source/tests, and evidence-linked references first; expand only when a concrete dependency, test, or safety invariant requires it.

## Mode routing context read matrix

Use this first-screen matrix before expanding context. Load the required files/sections for the active mode, add optional context only when evidence requires it, and stop before avoid sections unless the caller changes scope.

| Mode | Required files / sections | Optional expansion | Stop / avoid |
|---|---|---|---|
| Parent orchestrator | Project rulebook; [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe); [BUILD-FLOW.md §Multiple issue worktree mode](BUILD-FLOW.md#multiple-issue-worktree-mode); [Decoupling Contract](../docs/decoupling-contract.md) when multiple issues are in scope. | [issue-delivery-loop/SKILL.md](../issue-delivery-loop/SKILL.md) for batch loops; [BUILD-FLOW.md §Post-merge verifier recipe](BUILD-FLOW.md#post-merge-verifier-recipe) only after authorized finish. | Child implementation details after launch, reviewer internals beyond minimal launch prompt, and direct approve/merge/auto-merge commands unless authority and role allow them. |
| Standalone builder | Project rulebook; [SAFETY.md](SAFETY.md); [BUILD-FLOW.md §Implementation flow](BUILD-FLOW.md#implementation-flow); [BUILD-FLOW.md §Mandatory review gate](BUILD-FLOW.md#mandatory-review-gate); review packet template. | `tdd` skill for behavior work; [BUILD-FLOW.md §Check gate discovery](BUILD-FLOW.md#check-gate-discovery); [BUILD-FLOW.md §Stuck protocol](BUILD-FLOW.md#stuck-protocol). | Parent-orchestrator recipe unless coordinating child agents; post-merge verification unless separately assigned; self-approval, self-merge, or fallback finish actions. |
| Child `mr-builder` | Project rulebook; [SAFETY.md](SAFETY.md); [BUILD-FLOW.md §Child `mr-builder` mode](BUILD-FLOW.md#child-mr-builder-mode); [BUILD-FLOW.md §Implementation flow](BUILD-FLOW.md#implementation-flow); [templates/reviewer-lift-schema.md](templates/reviewer-lift-schema.md); [templates/builder-final-handoff.md](templates/builder-final-handoff.md). | `tdd` skill for behavior work; [BUILD-FLOW.md §Check gate discovery](BUILD-FLOW.md#check-gate-discovery); [BUILD-FLOW.md §Stuck protocol](BUILD-FLOW.md#stuck-protocol); affected issue-linked docs/tests only. | Avoid [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe), [BUILD-FLOW.md §Reviewer launch protocol](BUILD-FLOW.md#reviewer-launch-protocol), merge/finish action sections such as [`gitlab-local` finish guidance](../gitlab-local/SKILL.md#snippet-finish-mr-authority-aware), and [BUILD-FLOW.md §Post-merge verifier recipe](BUILD-FLOW.md#post-merge-verifier-recipe) unless parent changes role scope. |
| Revision builder | Review findings and reviewed SHA; [BUILD-FLOW.md §Implementation flow](BUILD-FLOW.md#implementation-flow) revision/post-ready rules; [templates/revision-packet.md](templates/revision-packet.md); [templates/reviewer-lift-schema.md](templates/reviewer-lift-schema.md). | Targeted tests for each finding; full gate evidence; `tdd` skill when revision touches behavior. | Reusing stale review evidence, silently pushing after ready, resolving reviewer threads unless project policy allows it, or spawning a reviewer in child mode. |
| Docs-only/config-only builder | Project rulebook; affected docs/config; [templates/review-packet-compact.md](templates/review-packet-compact.md); [BUILD-FLOW.md §Compact packet eligibility](BUILD-FLOW.md#compact-packet-eligibility); repo [Check Gate](../docs/agents/check-gate.md). | Markdown/link checks; [BUILD-FLOW.md §Check gate discovery](BUILD-FLOW.md#check-gate-discovery); relevant docs ownership map. | Skip `tdd` and record `TDD: N/A` unless behavior becomes touched; avoid runtime/operator/safety behavior sections when no such surface changes. |
| Multi-issue coordinator | Supplied issues; [BUILD-FLOW.md §Multiple issue worktree mode](BUILD-FLOW.md#multiple-issue-worktree-mode); [Decoupling Contract](../docs/decoupling-contract.md); source branch/worktree plan. | [BUILD-FLOW.md §Parent-orchestrator recipe](BUILD-FLOW.md#parent-orchestrator-recipe) when delegating; [reference/multiple-worktrees.md](reference/multiple-worktrees.md) for detailed worktree setup. | Parallel work when any decoupling item is false/unknown; coding in the coordinator checkout; combining Review Packets or shared run artifacts across issues. |

## Quick start

1. Load `gitlab-local` and run **Snippet: local-repo-preflight** to verify `glab`/`jq` are installed, authenticated, and the cwd is the intended GitLab repo.
2. Read [SAFETY.md](SAFETY.md) before changing files.
3. Read [BUILD-FLOW.md](BUILD-FLOW.md) before selecting issue(s), creating/updating MR(s), commenting, or marking ready.
4. Resolve the issue(s): supplied IDs/URLs, or pick one (or a decoupled set) from the current project.
5. Start clean: `git status --porcelain` empty, `git fetch origin`, default branch detected, `origin/<default>` current. If dirty/stale, stop and ask.
6. Single issue → branch from latest default in cwd. Multiple issues → one sibling worktree per issue from `origin/<default>`; never share a checkout.
7. Open a Draft MR early per issue once the source branch exists remotely with `gitlab-local` **Snippet: draft-mr-create**, `Closes #<id>`, and the appropriate Review Packet template. Use **Snippet: mr-description-update** for later description / Reviewer Lift refreshes. Fill the **Reviewer Lift** block using `templates/reviewer-lift-schema.md` so the reviewer can copy structured values directly into their report. Quote `Merge authority` as a claim and fill `Merge authority source`; the builder cannot grant approval, merge, or auto-merge authority.
8. For behavior-touching work, follow `tdd`. For docs/config-only, state TDD: N/A in the MR.
9. Run the project's full check gate per MR/worktree, or explain why only CI can provide it. Update the MR description with `gitlab-local` **Snippet: mr-description-update** (including every field from the Reviewer Lift schema, especially `Merge authority source`) and then mark ready with **Snippet: draft-mr-mark-ready** when the local gate is green.
10. **Review-gate handoff** — after marking ready, follow the invocation mode above: standalone builders spawn a fresh reviewer per the [Mandatory review gate](BUILD-FLOW.md#mandatory-review-gate) protocol; child `mr-builder` agents stop at final handoff for the parent orchestrator.

## Issue pickup summary

When the user supplies issue IDs/URLs, use them if suitable. Otherwise pick from the **current GitLab project**: prefer open issues assigned to `@me` or unassigned, ready/triaged, clear, unblocked, and fit one MR. For multiple issues, keep only a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md). Deprioritize blocked issues, issues with the project's information-needed or human-decision equivalent, in-progress/WIP items, and confidential/security-sensitive issues unless explicitly requested. See [BUILD-FLOW.md §Issue pickup](BUILD-FLOW.md#issue-pickup) for the full procedure using `gitlab-local` snippet names.

## Essential safety summary

- No live product/runtime/operator external mutations during development/review unless the human explicitly requested an operator action. GitLab issue/MR actions prescribed by this workflow are allowed.
- Never touch, print, summarize, commit, or paste credentials or sensitive payloads.
- Don't weaken safety gates, locks, sequencing, immutable baselines, schemas, migrations, or deploy topology casually.
- Use project adapters for external APIs; new raw HTTP/SDK/CLI calls require ADR-level justification.
- Every behavior change needs meaningful tests and regression evidence.
- Behavior-touching implementation follows TDD unless impossible; exceptions must be explicit in the MR.
- Keep scope tight; file follow-up GitLab issues instead of drive-by refactors.

See [SAFETY.md](SAFETY.md) for non-negotiables, refactor rules, quality rules, escalation, and done criteria.

## Templates

- `templates/reviewer-lift-schema.md` — canonical Reviewer Lift field names, order, and required semantics.
- `templates/builder-final-handoff.md` — machine-readable child-builder final response block for parent-orchestrator parsing.
- `templates/review-packet.md` — full MR description.
- `templates/review-packet-compact.md` — compact MR description for simple changes.
- `templates/build-plan-packet.md` — pre-edit discovery packet for issue, intended behavior, affected surfaces, test plan, risk, and non-goals.
- `templates/revision-packet.md` — comment for responding to review.
- `templates/stuck-packet.md` — comment when blocked >2h.
- `templates/filling-guide.md` — section-by-section filling instructions for builder templates.
- `templates/adr.md` — committed under `docs/adr/NNN-kebab-title.md` via its own MR; see shared `../templates/filling-guide.md`.

## Done

See [SAFETY.md §Done criteria](SAFETY.md#done-criteria) for the canonical completion checklist.
