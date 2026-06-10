---
name: retro
description: >-
  Delivery retrospective for GitLab build/review workflows: mine the
  just-finished session or batch (conversation, batch metrics, MRs, Review
  Reports, blocker tokens, local state) for friction evidence, then propose
  bounded improvements to flow, process, context, and taxonomy as routed
  follow-up issues. Use after a /start-build, /start-review, or
  /issue-delivery-loop run, when asked for a retro / retrospective / lessons
  learned on agent delivery work, or to turn per-batch delivery metrics into
  improvement issues.
---

# Retro

Close the delivery feedback loop: the build/review/delivery skills report metrics, rounds, and blockers — this skill consumes them. It turns the evidence of one run into bounded improvement proposals. Proposal-only: like `memory-retrospective`, it never edits skills, templates, docs, gates, or tests directly; accepted proposals route to `/gitlab-to-issues` (or `/to-issues` when the target tracker is not GitLab) and ship through the normal build/review workflow.

This skill is project-agnostic and runs from any target repo. Project-specific facts — live labels, Check Gate commands, doc ownership, workflow policy — come from the target repo's Agent Setup Docs and `project_profile` hooks at run time; never assume the skills repo's own layout or vocabulary in a finding.

## Use when

- a `/issue-delivery-loop` batch or a `/start-build` + `/start-review` session just finished
- the user asks for a retro, retrospective, post-batch review, or lessons learned on agent delivery work
- per-batch metrics from the `issue-delivery-loop` operating contract exist and nothing has consumed them

Not this skill: longitudinal claude-mem aggregate mining (`/memory-retrospective`), repo cleanup discovery (`/cleanup-codebase`), or reviewing a diff (`/start-review`).

## Operating contract

- **Evidence-first.** Every finding carries claim / evidence / source — the same discipline as the Review Context Capsule. One anecdote is a `monitor`; a repeat is a pattern.
- **Read-only collection.** Use `/gitlab` read snippets and read-only git/file inspection. Never mutate MRs, issues, labels, branches, or worktrees while collecting. The only mutations this skill leads to are the follow-up issues the user approves.
- **Current context first.** The primary input is the run at hand: conversation evidence, builder/reviewer final handoffs, Review Reports, revision rounds, blocker tokens, Gate Receipts, batch metrics, and local leftovers. Expand to claude-mem or older GitLab history only to confirm whether a friction is recurring.
- **Safety floors are not retro material.** Never propose weakening the hard floors in [Effort Scaling](skill://retro/docs/effort-scaling.md): mandatory independent review gate, TDD for behavior-touching work, SHA/CI/authority guards, Context Firewall, child-builder and verifier boundaries, MCP-first transport correctness. A proposal that touches one is classified `human-decision` and stops there.
- **Route, don't edit.** Map each accepted finding to the doc or skill that owns the behavior, using the target repo's rulebook / Agent Setup Docs ownership map (`CLAUDE.md`, `docs/agents/...` or equivalent) for project policy and the owning Agent Skill for workflow behavior. Then decide which tracker the issue belongs in: the target project's repo for project policy/setup findings, or the repo that owns the skill for reusable workflow findings — a fix filed in the wrong repo either gets lost or forks the skill locally.

## Flow

1. **Bound the retro.** Name the batch/session, the issue/MR IIDs in scope, and the time range. Ask only when scope is genuinely ambiguous.
2. **Collect evidence (read-only).** Batch metrics; per-MR review rounds and verdicts; `Action blocker` / `blocker_token` values; Gate Receipts and gate outcomes; timeout/stale/interrupted rounds; transport fallbacks and repeated workarounds; local state (`git worktree list`, `git for-each-ref refs/tmp`, `git status --porcelain`, gate result on the fresh default branch); ceremony-vs-tier fit per [Effort Scaling](skill://retro/docs/effort-scaling.md).
3. **Scan the signal catalogue.** Walk [reference/signal-catalogue.md](reference/signal-catalogue.md) and record hits with evidence. The catalogue is a checklist, not a cap — record any evidence-backed friction even when no row matches.
4. **Classify findings.** One `RF-N` per finding using the taxonomy below. Dedupe by root cause, not by symptom; three symptoms of one cause are one finding.
5. **Draft the Retro Report** from [templates/retro-report.md](templates/retro-report.md): summary first, metrics table, what went well, findings, safety floor check, routing plan.
6. **Confirm routing with the user**, then file accepted `adopt` / `experiment` findings as issues via `/gitlab-to-issues` (or `/to-issues`) in the repo chosen by the Route-don't-edit rule, using that repo's live triage labels. `monitor` findings stay in the report for the next retro. `human-decision` findings are escalated as questions, not filed as fix issues.

## Finding taxonomy

Categories (definitions in the [signal catalogue](reference/signal-catalogue.md)):

- `flow` — ordering, handoff, or routing problems between roles.
- `process` — ceremony/effort miscalibration and policy friction.
- `context` — context loading and size problems: re-reads, restated canon, bloated prompts.
- `taxonomy` — vocabulary gaps and collisions: events forced into `other`, undefined metrics, one concept under several names.
- `tooling` — transport/helper/runtime defects and repeated workarounds.
- `docs-drift` — canonical docs disagreeing with each other or with observed behavior.

Dispositions: `adopt` (clear bounded fix), `experiment` (try and measure), `monitor` (insufficient evidence yet), `human-decision` (touches a safety floor or a product/policy choice).

Required fields per finding: category, disposition, claim, evidence + source, owner doc, bounded proposal, expected effect, metric to watch.

## Safety

- Never print secrets, credentials, auth headers, or sensitive payloads in reports or issues; redact with `[REDACTED]`.
- Never paste full session dumps; cite the smallest excerpt or a locator that backs the claim.
- Read-only while collecting; no GitLab mutations except user-approved follow-up issue creation through `/gitlab-to-issues`.
- Do not overfit: a single bad round is rarely a process defect. Prefer `monitor` over speculative churn.

## Templates

- [templates/retro-report.md](templates/retro-report.md) — Retro Report shape with stable `RF-N` IDs, metrics table, safety floor check, and routing plan.
- [reference/signal-catalogue.md](reference/signal-catalogue.md) — friction signal inventory with detection sources and category definitions.
