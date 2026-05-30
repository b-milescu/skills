---
name: cleanup-housekeeping
description: Discover and plan repo-maintenance cleanup as subtractive work — deslop (behavior- and boundary-preserving simplification of needlessly complex local structures) and destale (remove or correct stale/inaccurate code, docs, config, deps, CI). Planning-only; routes implementation to the build workflow. Not for boundary-moving refactoring (use `improve-codebase-architecture`), diff-level tidy-ups (use `simplify`/`code-review`), or issue triage (use `triage`). Use when the user asks for cleanup, deslop, removing dead/duplicated/stale code or docs, or repo-hygiene discovery.
---

# Cleanup Housekeeping

Operate as a **relentless subtractive auditor**: exhaustive within the declared scope, evidence-gated, behavior- and boundary-preserving, and unwilling to cut without proof — every cut is proven safe within a declared blast radius or it routes to `Needs info`. Discover and plan **subtractive** maintenance in two tight, evidence-gated scopes: **deslop** (simplify needlessly complex local structures without changing behavior or boundaries) and **destale** (remove or mechanically correct stale/inaccurate items). Planning-only by default: do not edit source, delete files, upgrade dependencies, reformat code, or run destructive commands; approved slices go to the build workflow, not this skill.

## Operating stance

- **Evidence first, language agnostic:** infer ecosystems from repo evidence, never from filenames alone; every candidate **MUST** carry concrete file, command, doc, or test evidence, or it is not a candidate.
- **Project rules first:** read the host rulebook (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README, `docs/agents`, `CONTEXT.md`, ADRs) before judging cleanup value — rules outrank instinct.
- **Domain-safe, fail-closed:** cleanup **MUST** preserve domain language, safety invariants, review gates, deploy topology, migrations, and operator workflows; when you cannot prove a structure is incidental, leave it.
- **Exhaustive in coverage, restrained in severity:** sweep the whole declared scope and leave no debt unexamined — but route nits, style, and judgment calls to `Needs info` or a handoff; never inflate trivia into a blocking finding.
- **Planning-only by default:** produce scoped plans, risks, validation, and follow-up questions; leave implementation to the build workflow.

## Scope 1 — DESLOP (behavior- AND boundary-preserving simplification)

*Observable behavior* = return values, exceptions (type+message), side effects, emitted text (logs/stdout other code may parse), ordering, rounding, **and time/space complexity class**; a consumer relying on any of these must not be able to tell. **Allowed transforms — CLOSED list** (anything not on it → `improve-codebase-architecture`, not deslop):

- remove dead/unreachable code
- remove a literal/near-literal duplicate where a canonical copy exists in-reach (cross-unit dedup is OUT)
- inline a private, single-call-site pass-through wrapper that only forwards
- remove speculative/unused generality (params/config/extension points with no current consumer)
- remove vestigial leftovers (commented-out code, dead flags, shims for removed features)
- flatten **provably-equivalent** local control flow (nested-if → guard, collapse identical branches)
- replace hand-rolled code with an existing helper/stdlib at the same call site with identical contract

**Gate sequence** (apply per candidate; any *yes/unknown* → OUT or `Needs info`):

1. **Export gate** — exported/public/referenced across a module boundary? → OUT
2. **Reference gate** — within a *declared observability budget* (this file + direct importers + tests/fixtures, listed in the candidate Evidence), referenced by any other unit incl. tests/mocks/reflection/DI/dynamic access? → OUT
3. **Incidental-contract gate** — changes exception/message, log format, complexity class, ordering, rounding, or side-effect timing? → OUT
4. **Domain gate** — could the structure *be* a domain rule (branch table, tier, state machine) and you cannot show it is incidental? → OUT
5. **Edge gate** — creates/removes/relocates an edge between units (incl. cross-unit dedup)? → OUT

Survives all five ⇒ in-scope. The candidate MUST state the observability budget it inspected; an unstated/unbounded budget ⇒ `Needs info`, never AFK. Behavior-touching simplification stays **HITL + requires characterization tests**. **Firewall:** *simplify inside the unit; never move a seam — only via the allowed transforms, each proven unobservable within a declared blast radius.* Treat every transform as observable until you have proven otherwise; an unproven transform is OUT, not a judgment call.

## Scope 2 — DESTALE (remove or correct stale/inaccurate items)

Code, docs, config, deps (upgrades as separate reviewable slices), CI, examples. **Correction is in-scope only when a single mechanical source of truth proves both the drift AND the corrected value** (command output, lockfile, config, code signature) — treat the stale text as a map, not truth, and never correct from inference; without that mechanical proof, the candidate is OUT. If the fix needs judgment, prose authoring, or a domain call → `Needs info` / `grill-with-docs`. ("Fix the drifted README command" is IN; "rewrite the README for clarity" is OUT.)

## Out of scope — handoffs (each carries a fallback)

- boundary-moving restructuring (split mixed-responsibility files, move responsibilities, change APIs/layers, cross-unit dedup) → `improve-codebase-architecture` *(fallback: file a boundary-change follow-up issue)*
- tracker/backlog hygiene (stale issues, labels, untriaged backlog) → `triage` *(fallback: repo tracker workflow)*
- unsafe-default / security assessment → `security-review`, flag-and-refer only *(built-in)*
- terminology / ADR / glossary → `grill-with-docs` *(fallback: edit `CONTEXT.md`/ADRs manually)*

## Boundaries with sibling skills

- **When NOT to use this skill:** if you already have a pending change/diff and just want it tidied → `/simplify` (or `/code-review`). Cleanup is for discovering debt across *committed* code with no active change.
- **Implementation route:** planning-only. Approved slices → the build workflow (`/start-build`), which produces the diff; `/simplify` + `/code-review` run *downstream* on that diff; the start-review structural maintainability sweep gates the same smells at MR time. **No direct cleanup→simplify edge** (a plan cannot be consumed by a diff-level applier).
- **vs the start-review structural sweep:** same smell taxonomy, different altitude — cleanup finds them repo-wide as plan candidates; the sweep gates them inside one MR diff. Do not merge.
- **Subagent fan-out:** the default posture for discovery — fan out read-only subagents to sweep the repo broadly; narrow to a single pass only when the user explicitly scopes the work to a narrow, path-limited, or docs-only pass.

## Quick start

1. Default to a repo-wide sweep; confirm scope only to narrow it (path-limited, docs-only, config-only, dependency hygiene, or a specific concern).
2. Resolve repo root and cleanliness with read-only commands (`git rev-parse --show-toplevel`, `git status --porcelain`); a dirty worktree means call out possible noise. Load project context: rulebook, README/CONTRIBUTING, `docs/agents/*`, check-gate docs, `CONTEXT.md`, and ADRs.
3. By default, fan out read-only discovery subagents for a broad repo-wide sweep (see Boundaries); narrow to a single pass only when the user explicitly scopes the work down.
4. Discover ecosystems from manifests/config/CI, then build the candidate list (deslop and destale), applying the deslop gate sequence and the destale source-of-truth gate.
5. Present the proposal; ask which slices to approve, defer, merge, split, or discard.
6. After approval, route to `/to-issues` or `/gitlab-to-issues` for issue creation; route implementation to the build workflow, not this skill.

## Graphify-assisted discovery (optional lead-gen)

- Use graphify as a lead generator for broad, unfamiliar, or relationship-heavy scopes. If `graphify-out/graph.json` or `graphify-out/GRAPH_REPORT.md` exists, inspect it; if missing or stale, recommend `/graphify . --update` only when scope justifies it and ask before creating or updating graph artifacts. Do not require graphify for narrow, docs-only, config-only, or dependency-only passes.
- Treat graph findings (especially `INFERRED`/`AMBIGUOUS` edges) as **leads, not evidence**. A finding supported only by graph output is `Needs info`. Verify every candidate with source files, docs, tests, CI, commands, or tracker evidence.

## Candidate template

- **Title**: action-oriented cleanup slice (deslop or destale).
- **Evidence**: files, commands, docs, or observations; for deslop, the **declared observability budget** inspected; note any graph lead and edge confidence.
- **Why now**: maintenance pain, risk reduction, reviewability, onboarding, CI clarity.
- **Scope**: included surfaces and explicit out of scope.
- **Risk**: behavior/runtime/operator/security/data/review impact.
- **Validation**: tests, check gate, docs link check, dry run, grep proof, graph query, or manual review.
- **Effort / Confidence**: S/M/L with reason; High/Medium/Low by evidence depth.
- **Type**: AFK / HITL / Needs info.

## Classification rules

- **AFK** — mechanical, reversible, scoped, acceptance criteria clear; normal review is still mandatory, never waived.
- **HITL** — behavior-touching deslop (characterization tests required) or any candidate with uncertain ownership/impact; uncertainty escalates, it never relaxes.
- **Needs info** — the fail-closed default: insufficient evidence, missing acceptance criteria, unstated/unbounded observability budget, no mechanical source of truth for a correction, or unclear check gate.

## Planning rules

- Prefer small surgical slices with independent review; separate pure docs, mechanical destale, dependency upgrades, and behavior-touching deslop unless coupling is proven, sequencing characterization tests first.
- Preserve generated files unless the generator/source of truth is known. From discovery mode: never delete, never rewrite history, never mass-format, never change locks, never upgrade dependencies.

## Output shape

1. **Scope inspected** — paths, docs, commands, known gaps, and graph context (not used / existing graph read / update recommended / update skipped).
2. **Top findings** — ranked table of deslop and destale candidates.
3. **Recommended plan** — ordered slices with type, risk, validation, and dependencies.
4. **Handoffs** — items routed to `improve-codebase-architecture`, `triage`, `security-review`, or `grill-with-docs`, each with its fallback.
5. **Next step** — approve slices, convert to issues, run/update graphify, or widen/re-scope discovery.
