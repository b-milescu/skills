---
name: retro
description: >-
  Delivery retrospective: turn build/review/delivery friction evidence into
  bounded, routed follow-up issues. Use after a start-build, start-review, or
  issue-delivery-loop run, when asked for a retro / retrospective / lessons
  learned on agent delivery work, or to turn per-batch delivery metrics into
  improvement issues.
---

# Retro

Close the delivery feedback loop: the build/review/delivery skills report metrics, rounds, and blockers — this skill consumes them. It turns delivery evidence into bounded improvement proposals at two scopes: `batch` (the just-finished run) and `lookback <date range>` (recurring friction across a window). Proposal-only: it never edits skills, templates, docs, gates, or tests directly; accepted proposals route to the `plan-to-issues` skill and ship through the normal build/review workflow.

This skill runs from the invoked target. Facts and policy come from its confirmed `project_profile`, `profile_path`, selected `provider.reference` and declared Agent Setup Doc paths; never from installed aliases or this repository's vocabulary. Bind only systems required by collection/publication through `forge preflight`; absent/stale setup prompts explicit owner setup, never automatic login/setup/install or live label mutation.

## Use when

The trigger conditions live in the skill description (just-finished build/review/delivery runs, an explicit retro/retrospective/lessons-learned request, or unconsumed per-batch metrics); the `lookback` scope additionally covers "what friction recurred across the last week/month of delivery work". Below are only the exclusions:

Not this skill: raw memory analytics or aggregate query mechanics (the active memory plugin's own reporting skills), repo cleanup discovery (the `cleanup-codebase` skill), or reviewing a diff (the `start-review` skill).

## Scopes

Pick one scope per run; both produce the same Retro Report and route findings through the same machinery (signal catalogue, `RF-N` taxonomy + dispositions, ownership mapping, the refuter pass, routing plan, and the safety-floor check).

- **`batch`** (default) — the just-finished `start-build` + `start-review` session or `issue-delivery-loop` batch. Behavior below is unchanged.
- **`lookback <date range>`** — recurring friction across an explicit date range. Bound the window first. This scope adds three behaviors on top of `batch`:
  - **Aggregate counts** by activity type / project / agent role / date range, as an *optional* Retro Report section, to show where effort concentrated.
  - **Active memory discovery with graceful degradation** — if a persistent memory skill or MCP is already loaded in this session, point at its search; if it is unavailable, say so and continue with repo and tracker evidence only. Raw query mechanics belong to that memory skill/MCP; this skill does not own query syntax.
  - **Date-range scoping** — every aggregate and finding is scoped to the named window; do not mix in evidence from outside it.

The don't-overfit-to-anecdotes rule (Safety, below) applies to both scopes: one anecdote is a `monitor`, not a process defect.

## Operating contract

- **Evidence-first.** Every finding carries claim / evidence / source — the same discipline as the Review Context Capsule. One anecdote is a `monitor`; a repeat is a pattern.
- **Refute before presenting.** A finding the drafter never argued against is a guess with citations. Every report crosses one refuter pass before the user sees it, and each surviving finding carries the strongest counter-argument it beat.
- **Read-only collection.** Use `forge snapshot` and read-only git/file inspection. Never mutate change requests, issues, labels, branches, or worktrees while collecting. The only mutations this skill leads to are the follow-up issues the user approves.
- **Current context first.** The primary input is the run at hand: conversation evidence, builder/reviewer final handoffs, Review Reports, revision rounds, blocker tokens, Gate Receipts, batch metrics, and local leftovers. Expand to the active memory plugin/MCP if present, or older tracker history only to confirm whether a friction is recurring.
- **Session-first MCP evidence (both scopes).** Bound MCP evidence to the scoped sessions' own calls, outputs, and documented unavailability. Only when needed and available, inspect implicated, identified local metadata, source, or already-sanitized logs; state unavailable evidence and uncertainty about whether local source corresponds to the running server. No observed MCP friction means no additional local-tooling investigation.
- **Safety floors are not retro material.** Never propose weakening the [safety-floor litany](<../start-build/SAFETY.md#safety-floors>). A proposal that touches one is classified `human-decision` and stops there.
- **Route, don't edit.** Map each accepted finding to the evidenced implementation, configuration, documentation, or skill owner, with repository and component/file locator when known; unresolved ownership stays `unknown`. Use the target repo's rulebook / Agent Setup Docs ownership map for project policy and the owning Agent Skill for workflow behavior. Route to the repository that owns the cause, not the symptom; [ownership guidance](reference/signal-catalogue.md#ownership-mapping-hints) requires causal evidence before proposing a fix.

## Flow

1. **Bound the retro.** Name the batch/session, the issue/change-request IDs in scope, and the time range. Ask only when scope is genuinely ambiguous.
2. **Collect evidence (read-only).** Batch metrics; per-change request review rounds and verdicts; `Action blocker` / `blocker_token` values; Gate Receipts and gate outcomes; timeout/stale/interrupted rounds; transport fallbacks and repeated workarounds; local state (`git worktree list`, `git for-each-ref refs/tmp`, `git status --porcelain`, gate result on the fresh default branch); observed ceremony cost (unnecessary packets, analysis/verification fan-out and repeated context reads) against the decisions and risks they actually addressed.

   **Complete when:** every source above is inspected or marked `N/A — <why>`.
3. **Scan the signal catalogue.** Walk [reference/signal-catalogue.md](reference/signal-catalogue.md) and record hits with evidence.
4. **Classify findings.** One `RF-N` per finding. Dedupe by root cause, not by symptom; three symptoms of one cause are one finding.
5. **Draft the Retro Report** from [templates/retro-report.md](templates/retro-report.md): summary first, metrics table, what went well, findings, safety floor check, routing plan. Number findings `RF-N` in report order and keep those IDs stable once follow-up issues cite them.
6. **Refute the draft.** Launch one read-only refuter subagent (the harness picks the agent type) with a fresh context, the draft report, and the evidence locators — not the collection reasoning. It re-derives each finding from its cited source and returns one verdict per `RF-N` using [reference/refutation.md](reference/refutation.md). Apply every verdict before the report leaves the session.

   **Complete when:** the independent refuter has assigned every `RF-N` a verdict, every survivor includes its strongest counter-argument and response, and the report includes the refuter's safety-floor attestation. With zero findings, the refuter still checks the report and supplies that attestation. Evidence and metrics may be `N/A — <why>`; unavailable refutation leaves an explicitly unrefuted draft, not a complete report.
7. **Present the refuted report, confirm routing with the user**, then file accepted `adopt` / `experiment` findings as issues via the `plan-to-issues` skill in the repo chosen by the Route-don't-edit rule, using that repo's live triage labels. `monitor` findings stay in the report for the next retro. `human-decision` findings are escalated as questions, not filed as fix issues.

## Finding taxonomy

Categories — `flow`, `process`, `context`, `taxonomy`, `tooling`, `docs-drift` — are defined in the [signal catalogue](reference/signal-catalogue.md#category-definitions).

Dispositions: `adopt` (clear bounded fix), `experiment` (try and measure), `monitor` (insufficient evidence yet), `human-decision` (touches a safety floor or a product/policy choice).

## Safety

- Never print secrets, credentials, auth headers, or sensitive payloads in reports or issues; redact with `[REDACTED]`.
- Never paste full session dumps; cite the smallest excerpt or a locator that backs the claim.
- Inspect only identified, implicated local evidence under the session-first contract. Never scan the machine/home broadly, dump credentials, or load credential-bearing logs merely to redact them afterward; use already-sanitized evidence or mark it unavailable.
- Never replay mutating calls, restart servers, or change configuration to collect evidence.
- Read-only while collecting; no tracker mutations except user-approved follow-up issue creation through the `plan-to-issues` skill.
- Do not overfit: a single bad round is rarely a process defect. Prefer `monitor` over speculative churn.
