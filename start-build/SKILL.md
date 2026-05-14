---
name: start-build
description: Starts build tasks by picking up and implementing one or more scoped GitLab issues for the current project, using test-driven development for behavior-touching changes. It can discover/select open issues via glab, use isolated git worktrees for multiple decoupled issues, branch from main/default, implement with red-green-refactor slices, run the project's check gate, open Draft GitLab MRs with Review Packets, and handle review revisions. Use when the user asks to start a build, pick up/build/implement issue(s), address GitLab issue(s), fix bugs, add features, or open Merge Requests.
---

# Start Build

## Purpose

Implement scoped GitLab issues and produce reviewable changes: code, tests, docs, migrations, MRs. Single-issue is the default. Multiple issues are allowed only when clearly decoupled; each gets its own branch, worktree, MR, check evidence, and Review Packet. Treat every project as safety-critical unless its rulebook says otherwise.

This skill is language- and domain-agnostic; domain-specific safety terms below are examples to map onto the host project's equivalent surfaces. **Load the host project's rulebook first** (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, architecture docs, ADRs). Project rules override this skill where stricter. Handoff lives in **GitLab**: tasks are issues, proposals are MRs, review happens in MR discussions. Fill templates into MR descriptions/comments; never commit `.reviews/` artifacts.

For runtime/operator/safety behavior changes, load and follow the `tdd` skill. If TDD is not applicable (docs-only, mechanical rename, generated update, urgent hotfix), say why in the MR.

## Quick start

1. Load `local-gitlab` and run its direct-`glab` preflight to verify `glab` is installed/authenticated and the cwd is the intended GitLab repo.
2. Read [SAFETY.md](SAFETY.md) before changing files.
3. Read [BUILD-FLOW.md](BUILD-FLOW.md) before selecting issue(s), creating/updating MR(s), commenting, or marking ready.
4. Resolve the issue(s): supplied IDs/URLs, or pick one (or a decoupled set) from the current project.
5. Start clean: `git status --porcelain` empty, `git fetch origin`, default branch detected, `origin/<default>` current. If dirty/stale, stop and ask.
6. Single issue → branch from latest default in cwd. Multiple issues → one sibling worktree per issue from `origin/<default>`; never share a checkout.
7. Open a Draft MR early per issue once the source branch exists remotely (push the first commit or use `glab mr create --push`) with `Closes #<id>` and the appropriate Review Packet template. Fill the **Reviewer Lift** block using the stable handoff schema so the reviewer can copy structured values directly into their report: Reviewed SHA, CI pipeline, Local gate, RED/GREEN, Changed paths, Touched safety surfaces, Decoupling proof, Reviewer Focus, Open Questions, Merge authority, and Delta since last ready push.
8. For behavior-touching work, follow `tdd`. For docs/config-only, state TDD: N/A in the MR.
9. Run the project's full check gate per MR/worktree, or explain why only CI can provide it.
10. Update the MR description (including the full Reviewer Lift schema), mark ready, and request review (`start-review` or human) via the project-approved protocol. **Don't wait for CI when the local gate is green** — see [BUILD-FLOW.md](BUILD-FLOW.md) §Implementation flow step 9 for the narrow exceptions and the CI-pending review policy. **If you push commits after marking ready**, post a delta comment with old SHA → new SHA, reason, changed files, gate rerun, and whether the delta is substantive; update Reviewer Lift's `Reviewed SHA`, `CI pipeline`, and `Delta since last ready push`. Use the Revision Packet for substantive post-ready changes. Same GitLab username/PAT for builder and reviewer is allowed.

## Essential tooling

Use the host project's issue-tracker guide as the single source of truth for `glab` command snippets and flag pitfalls. If the project has none, load `local-gitlab`. Keep this skill focused on workflow and handoff policy.

Minimum invariants still apply everywhere: `glab` must be installed/authenticated, direct preflight from `local-gitlab` must pass before GitLab operations, file-backed MR descriptions/comments should use direct `glab ... --description "$(cat file)"` / `glab ... --message "$(cat file)"`, and secrets must never be pasted into MR descriptions, comments, CI logs, or screenshots. If a project has no issue-tracker guide, verify syntax with `glab <subcommand> --help` and stop on auth/repo ambiguity.

## Issue pickup summary

When the user supplies issue IDs/URLs, use them if suitable. Otherwise pick from the **current GitLab project**:

- Prefer open issues that are unassigned or `@me`, ready/triaged, clear, unblocked, fit one MR.
- For multiple, select only a clearly decoupled set: no dependency/order relation, no expected file/schema/lock/deploy/lockfile overlap, independently testable.
- Deprioritize blocked, needs-info, needs-human, in-progress/WIP, confidential/security-sensitive issues unless explicitly requested.
- Inspect candidates with `glab issue view <id>`; summarize ID, title, labels, assignee, suitability, coupling risk.
- If one issue/set is clearly best, announce and proceed. If several are plausible or coupled, ask the user to choose.
- Claim issues only when project convention is clear; do not create/mutate labels casually.

See [BUILD-FLOW.md](BUILD-FLOW.md) for the full pickup and GitLab workflow.

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

- `templates/review-packet.md` — full MR description.
- `templates/review-packet-compact.md` — compact MR description for simple changes.
- `templates/revision-packet.md` — comment for responding to review.
- `templates/stuck-packet.md` — comment when blocked >2h.
- `templates/adr.md` — committed under `docs/adr/NNN-kebab-title.md` via its own MR.

## Done

Every selected issue has its own MR approved; TDD/test evidence recorded or explicitly N/A; CI/check gate green, pending under protected auto-merge, or explicitly waived per MR; docs/runbooks updated; no secrets exposed; no live unintended product/runtime/operator external side effects; MRs merged only when merge authority allows; issues closed via `Closes #<id>` or project workflow.
