---
name: cleanup-housekeeping
description: Discover cleanup and housekeeping opportunities in any codebase, then propose and plan safe maintenance changes without implementing them by default. Use when the user asks for cleanup, housekeeping, repo hygiene, technical-debt discovery, stale code/docs/config inventory, or planning non-feature maintenance work.
---

# Cleanup Housekeeping

Discover, propose, and plan cleanup work. Default mode is planning-only: do not edit source, delete files, upgrade dependencies, reformat code, or run destructive commands unless the user explicitly pivots to an implementation workflow.

## Operating stance

- Language agnostic: infer ecosystems from repo evidence; never assume app stack from filenames alone.
- Evidence first: every recommendation needs concrete file, command, doc, tracker, or test evidence.
- Project rules first: read the host repo rulebook (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README, docs/agents, `CONTEXT.md`, ADRs) before judging cleanup value.
- Guardrail-aligned: when `docs/agents/coding-guardrails.md` exists, compare findings to it. Treat newer guardrails as target direction for existing code, not blame for older choices.
- Domain-safe: cleanup must preserve domain language, safety invariants, review gates, deploy topology, migrations, and operator workflows.
- Deep for repo-wide scans: avoid shallow sampling; use repo structure, docs, tests, and graph evidence when available.
- Mandatory subagent discovery: every cleanup run must launch read-only subagent discovery before final recommendations. Use broad fan-out for repo-wide scope and at least one narrow verifier/discovery child for path-limited scope. If subagents cannot be launched safely, stop and report the blocker instead of silently falling back to serial-only discovery.
- Planning-only by default: produce scoped plans, risks, validation, and follow-up questions; leave implementation to the user-approved build/review workflow.

## Quick start

1. Confirm scope if unclear: repo-wide, path-limited, docs-only, config-only, dependency hygiene, tracker hygiene, or specific concern.
2. Resolve repo root and check cleanliness with read-only commands (`git rev-parse --show-toplevel`, `git status --porcelain`). Dirty worktree means avoid broad rewrites and call out possible noise.
3. Load project context: rulebook, README/CONTRIBUTING, `docs/agents/*` when present, especially `docs/agents/coding-guardrails.md` and check-gate docs, plus `CONTEXT.md`/`CONTEXT-MAP.md` and ADRs.
4. Launch mandatory read-only subagent discovery. For broad scopes, split by independent surface (docs/domain, build/CI, dependencies/tooling, code health, config/ops, tracker/process, graph communities). For narrow scopes, launch at least one focused verifier/discovery child over the requested path or concern. Give each child narrow paths, project rules, banned actions (no edits, deletes, upgrades, reformatting, live mutations, or secret output), and candidate fields to return. If launch authority or safe isolation is unavailable, stop and ask the user to authorize subagents or explicitly choose a different non-`/cleanup-housekeeping` workflow.
5. For broad scopes, use `/graphify <path> --mode deep`, `/graphify <path> --update`, or graph queries when `/graphify` is installed or `graphify-out/` exists; otherwise state the gap and continue with structural scanning.
6. Discover ecosystems from manifests/config/CI, then inspect enough files to ground findings across the requested scope.
7. Build candidate list with evidence, impact, risk, effort, confidence, likely validation, dependencies, and guardrail alignment.
8. Challenge candidates against docs and domain terms. If terminology, boundaries, or durable decisions are unclear, use or recommend `/grill-with-docs` before finalising plan.
9. Present proposal; ask user which slices to approve, defer, merge, split, or discard.
10. After approval, route planning output to `/to-issues` or `/gitlab-to-issues` when issue creation is desired. Route implementation to the repo's build workflow, not this skill.

## Discovery checklist

Scan for cleanup opportunities across any language/toolchain:

- **Graph-backed discovery (when available)**: If `/graphify` is present or `graphify-out/` exists, use a deep or updated graph, `GRAPH_REPORT.md`, god nodes, communities, paths, and surprising connections to direct inspection.
- **Guardrail drift**: Compare candidates to `docs/agents/coding-guardrails.md` when present: hidden assumptions, overengineering, drive-by edits, broad refactors, orphan cleanup, missing success criteria, weak reproduction, or weak check evidence.
- **Subagent fan-out (mandatory, parent-owned)**: Parent/coordinator sessions must launch read-only discovery subagents before final recommendations. For broad scopes, split by independent surface (docs/domain, build/CI, dependencies/tooling, code health, config/ops, tracker/process, graph communities). For path-limited or focused scopes, launch at least one narrow verifier/discovery child over the requested surface. Give each child narrow paths, project rules, banned actions (no edits, deletes, upgrades, reformatting, live mutations, or secret output), and candidate fields to return.
- **Subagent aggregation**: Parent de-duplicates child findings, rejects unsupported claims, records gaps/conflicts, then classifies candidates as AFK/HITL/Needs info. If no launch authority or safe isolation exists, stop and report that `/cleanup-housekeeping` is blocked until subagent discovery is available or the user chooses another workflow.
- **Repo shape**: duplicate directories, abandoned modules, generated artifacts committed unexpectedly, unclear ownership, inconsistent naming, stale examples.
- **Docs/domain**: README drift, obsolete setup steps, broken doc links, ADR contradictions, glossary mismatch, missing operator/runbook notes.
- **Build/test/CI**: redundant scripts, stale workflow jobs, missing local check gate docs, flaky/skipped tests needing decision, unused fixtures.
- **Dependencies/tooling**: unused or duplicated packages, lockfile drift, unsupported runtime pins, overlapping formatters/linters. Propose upgrades only as separate reviewable slices.
- **Code health**: dead exports, duplicate helpers, TODO/FIXME clusters, large files with mixed responsibilities, inconsistent error handling. Treat behavior changes as higher risk.
- **Code simplification**: unnecessary abstractions, single-use wrappers, speculative extension points, deep nesting, duplicated control flow, over-generalized configuration, indirection that hides simple behavior, and complex conditionals that can be made clearer. Prefer behavior-preserving simplifications; require characterization tests for behavior-touching changes. Treat simplification that changes domain boundaries, safety invariants, public APIs, or operator workflows as HITL/high risk.
- **Config/ops**: stale env examples, duplicate config sources, unsafe defaults, obsolete deploy docs, secret-looking values. Never print secrets.
- **Tracker/process**: stale issues, missing labels, untriaged cleanup backlog, plans lacking acceptance criteria.

## Candidate template

For each finding, report:

- **Title**: action-oriented cleanup slice.
- **Evidence**: files, commands, docs, issues, or observations.
- **Why now**: maintenance pain, risk reduction, reviewability, onboarding, CI clarity, operator safety.
- **Scope**: included surfaces and explicit out of scope.
- **Risk**: behavior/runtime/operator/security/data/review impact.
- **Validation**: tests, check gate, docs link check, dry run, grep proof, graph query/update, CI job, or manual review.
- **Guardrail alignment**: coding guardrail, project rule, domain doc, or ADR this cleanup moves toward.
- **Effort**: S/M/L and reason.
- **Confidence**: High/Medium/Low based on evidence depth.
- **Type**: AFK / HITL / Needs info.

## Classification rules

- **AFK**: mechanical, reversible, scoped, and acceptance criteria are clear; normal review still required.
- **HITL**: architecture boundary, product behavior, security/legal, naming/domain decision, migration/deploy policy, or deletion with uncertain ownership.
- **Needs info**: insufficient evidence, missing acceptance criteria, blocked by unknown owner, unclear check gate, or uncertain runtime impact.

## Planning rules

- Prefer small vertical maintenance slices with independent review and validation.
- Keep cleanup proposals surgical: touch only needed files, avoid mass reformatting, and split broad refactors into reviewable slices.
- Separate pure docs, mechanical cleanup, dependency upgrades, behavior changes, and architecture changes unless coupling is proven.
- Sequence risk reducers first: characterization tests, docs clarification, check-gate repair, inventory scripts, then larger cleanup.
- Preserve generated files unless generator/source of truth is known.
- Never delete, rewrite history, mass-format, change locks, or upgrade dependencies from discovery mode.
- If cleanup reveals missing terminology or durable decisions, capture questions for `/grill-with-docs` and docs updates (`CONTEXT.md`, ADRs) before implementation.

## Output shape

1. **Scope inspected** — paths, docs, commands, graph sources if used, mandatory subagent coverage, and known gaps.
2. **Guardrails applied** — coding guardrails, project rules, check gate, domain docs, and ADRs used as evaluation criteria.
3. **Top findings** — ranked table of candidates.
4. **Recommended plan** — ordered slices with type, risk, validation, dependencies, and guardrail alignment.
5. **Grill points** — decisions or domain questions to resolve with `/grill-with-docs`.
6. **Next step** — approve slices, convert to issues, run/update graphify, or request deeper discovery.
