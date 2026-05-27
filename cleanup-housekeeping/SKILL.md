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
- Domain-safe: cleanup must preserve domain language, safety invariants, review gates, deploy topology, migrations, and operator workflows.
- Planning-only by default: produce scoped plans, risks, validation, and follow-up questions; leave implementation to the user-approved build/review workflow.

## Quick start

1. Confirm scope if unclear: repo-wide, path-limited, docs-only, config-only, dependency hygiene, tracker hygiene, or specific concern.
2. Resolve repo root and check cleanliness with read-only commands (`git rev-parse --show-toplevel`, `git status --porcelain`). Dirty worktree means avoid broad rewrites and call out possible noise.
3. Load project context: rulebook, README/CONTRIBUTING, `docs/agents/*` when present, `CONTEXT.md`/`CONTEXT-MAP.md`, ADRs, and check-gate docs.
4. Discover ecosystems from manifests/config/CI, then inspect only enough files to ground findings.
5. Build candidate list with evidence, impact, risk, effort, confidence, likely validation, and dependencies.
6. Challenge candidates against docs and domain terms. If terminology, boundaries, or durable decisions are unclear, use or recommend `/grill-with-docs` before finalising plan.
7. Present proposal; ask user which slices to approve, defer, merge, split, or discard.
8. After approval, route planning output to `/to-issues` or `/gitlab-to-issues` when issue creation is desired. Route implementation to the repo's build workflow, not this skill.

## Discovery checklist

Scan for cleanup opportunities across any language/toolchain:

- **Subagent fan-out (optional, parent-owned)**: For broad scopes, parent/coordinator sessions with launch authority may split read-only discovery by independent surface (docs/domain, build/CI, dependencies/tooling, code health, config/ops, tracker/process). Give each child narrow paths, project rules, banned actions (no edits, deletes, upgrades, reformatting, live mutations, or secret output), and candidate fields to return.
- **Subagent aggregation**: Parent de-duplicates child findings, rejects unsupported claims, records gaps/conflicts, then classifies candidates as AFK/HITL/Needs info. If no launch authority or safe isolation exists, run same checklist serially.
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
- **Validation**: tests, check gate, docs link check, dry run, grep proof, CI job, or manual review.
- **Effort**: S/M/L and reason.
- **Confidence**: High/Medium/Low based on evidence depth.
- **Type**: AFK / HITL / Needs info.

## Classification rules

- **AFK**: mechanical, reversible, scoped, and acceptance criteria are clear; normal review still required.
- **HITL**: architecture boundary, product behavior, security/legal, naming/domain decision, migration/deploy policy, or deletion with uncertain ownership.
- **Needs info**: insufficient evidence, missing acceptance criteria, blocked by unknown owner, unclear check gate, or uncertain runtime impact.

## Planning rules

- Prefer small vertical maintenance slices with independent review and validation.
- Separate pure docs, mechanical cleanup, dependency upgrades, behavior changes, and architecture changes unless coupling is proven.
- Sequence risk reducers first: characterization tests, docs clarification, check-gate repair, inventory scripts, then larger cleanup.
- Preserve generated files unless generator/source of truth is known.
- Never delete, rewrite history, mass-format, change locks, or upgrade dependencies from discovery mode.
- If cleanup reveals missing terminology or durable decisions, capture questions for `/grill-with-docs` and docs updates (`CONTEXT.md`, ADRs) before implementation.

## Output shape

1. **Scope inspected** — paths, docs, commands, and known gaps.
2. **Top findings** — ranked table of candidates.
3. **Recommended plan** — ordered slices with type, risk, validation, and dependencies.
4. **Grill points** — decisions or domain questions to resolve with `/grill-with-docs`.
5. **Next step** — approve slices, convert to issues, or request deeper discovery.
