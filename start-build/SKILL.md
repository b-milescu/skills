---
name: start-build
description: >-
  Implement GitLab issues: pick up scoped issues, TDD red-green-refactor slices,
  open Draft MRs with Review Packets, handle review revisions. Trigger: start a
  build, pick up/implement issue(s), fix bugs, add features, open MRs.
---

# Start Build

## Purpose

Implement scoped GitLab issues and produce reviewable changes: code, tests, docs, migrations, MRs. Operate as a **very senior software developer**: evidence-first, narrow-context, explicit about tradeoffs, and unwilling to invent facts. Single-issue is the default. Multiple issues are allowed only when clearly decoupled; each gets its own branch, worktree, MR, check evidence, and Review Packet. Treat every project as safety-critical unless its rulebook says otherwise.

This skill is language- and domain-agnostic; domain-specific safety terms below are examples to map onto the host project's equivalent surfaces. **Load the host project's rulebook first** (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, architecture docs, ADRs). Project rules override this skill where stricter. Handoff lives in **GitLab**: tasks are issues, proposals are MRs, review happens in MR discussions. Fill templates into MR descriptions/comments; never commit `.reviews/` artifacts.

> **Abbreviation:** `PRO` = product / runtime / operator (external systems).

For runtime/operator/safety behavior changes, load and follow the `tdd` skill. If TDD is not applicable (docs-only, mechanical rename, generated update, urgent hotfix), say why in the MR. Keep context as narrow as possible: issue, rulebook, affected docs/source/tests, and evidence-linked references first; expand only when a concrete dependency, test, or safety invariant requires it.

## Quick start

1. Load `gitlab-local` and run its direct-`glab` preflight to verify `glab` is installed/authenticated and the cwd is the intended GitLab repo.
2. Read [SAFETY.md](SAFETY.md) before changing files.
3. Read [BUILD-FLOW.md](BUILD-FLOW.md) before selecting issue(s), creating/updating MR(s), commenting, or marking ready.
4. Resolve the issue(s): supplied IDs/URLs, or pick one (or a decoupled set) from the current project.
5. Start clean: `git status --porcelain` empty, `git fetch origin`, default branch detected, `origin/<default>` current. If dirty/stale, stop and ask.
6. Single issue → branch from latest default in cwd. Multiple issues → one sibling worktree per issue from `origin/<default>`; never share a checkout.
7. Open a Draft MR early per issue once the source branch exists remotely (push the first commit or use `glab mr create --push`) with `Closes #<id>` and the appropriate Review Packet template. Fill the **Reviewer Lift** block using the stable handoff schema so the reviewer can copy structured values directly into their report: Reviewed SHA, CI pipeline, Local gate, RED/GREEN, Changed paths, Touched safety surfaces, Decoupling proof, Reviewer Focus, Open Questions, Merge authority, and Delta since last ready push.
8. For behavior-touching work, follow `tdd`. For docs/config-only, state TDD: N/A in the MR.
9. Run the project's full check gate per MR/worktree, or explain why only CI can provide it. Update the MR description (including the full Reviewer Lift schema) and mark ready when the local gate is green.
10. **Mandatory review gate** — after marking ready, spawn a subagent reviewer in a fresh session per the [Mandatory review gate](BUILD-FLOW.md#mandatory-review-gate) protocol.

## Issue pickup summary

When the user supplies issue IDs/URLs, use them if suitable. Otherwise pick from the **current GitLab project**: prefer open issues assigned to `@me` or unassigned, ready/triaged, clear, unblocked, and fit one MR. For multiple issues, keep only a clearly decoupled set — no dependency/order relation, no expected file/schema/lock/deploy/lockfile overlap, independently testable. Deprioritize blocked issues, issues with the project's information-needed or human-decision equivalent, in-progress/WIP items, and confidential/security-sensitive issues unless explicitly requested. See [BUILD-FLOW.md §Issue pickup](BUILD-FLOW.md#issue-pickup) for the full procedure with commands.

## Essential safety summary

- No live PRO external mutations during development/review unless the human explicitly requested an operator action. GitLab issue/MR actions prescribed by this workflow are allowed.
- Never touch, print, summarize, commit, or paste credentials or sensitive payloads.
- Don't weaken safety gates, locks, sequencing, immutable baselines, schemas, migrations, or deploy topology casually.
- Use project adapters for external APIs; new raw HTTP/SDK/CLI calls require ADR-level justification.
- Every behavior change needs meaningful tests and regression evidence.
- Behavior-touching implementation follows TDD unless impossible; exceptions must be explicit in the MR.
- Keep scope tight; file follow-up GitLab issues instead of drive-by refactors.

See [SAFETY.md](SAFETY.md) for non-negotiables, refactor rules, quality rules, escalation, and done criteria.

## Templates

- `templates/review-packet.md` — full MR description.
- `templates/review-packet-compact.md` — compact MR description for simple changes.
- `templates/revision-packet.md` — comment for responding to review.
- `templates/stuck-packet.md` — comment when blocked >2h.
- `templates/filling-guide.md` — section-by-section filling instructions for builder templates.
- `templates/adr.md` — committed under `docs/adr/NNN-kebab-title.md` via its own MR; see shared `../templates/filling-guide.md`.

## Done

See [SAFETY.md §Done criteria](SAFETY.md#done-criteria) for the canonical completion checklist.
