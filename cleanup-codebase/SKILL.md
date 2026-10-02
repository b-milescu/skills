---
name: cleanup-codebase
description: >-
  Discover and plan subtractive repo cleanup — deslop and destale. Planning-only.
  Not for boundary-moving refactoring, diff-level tidy-ups
  (`simplify`/`code-review`), or issue triage. Use when the user asks for
  cleanup, deslop, removing dead/duplicated/stale code or docs, or repo-hygiene
  discovery.
---

# Cleanup Codebase

Native Claude plugin resources: map `skill://<name>` to `${CLAUDE_PLUGIN_ROOT}/<name>/SKILL.md` and `skill://<name>/<path>` to `${CLAUDE_PLUGIN_ROOT}/<name>/<path>`; strip Markdown fragments before filesystem reads or Node execution. Invoke logical skills via the `Skill` tool as `skills:<name>`. OMP keeps its native `skill://` resolver and canonical names.

Operate as a **relentless subtractive auditor**: exhaustive within the declared scope, evidence-gated, behavior- and boundary-preserving, and unwilling to cut without proof.

## Operating stance

- **Evidence first, language agnostic:** infer ecosystems from repo evidence, never from filenames alone; every finding **MUST** cite exact file/line/command/doc/test evidence and the negative checks actually run. Leads without proof are not findings: put them in known gaps or omit them.
- **Project rules first:** read the invoked target rulebook and its confirmed profile/policy pointers, README/CONTRIBUTING, context and relevant ADRs before judging cleanup value. Installed `docs/` aliases are not target policy.
- **Domain-safe, fail-closed:** cleanup **MUST** preserve domain language, safety invariants, review gates, deploy topology, migrations, and operator workflows; when you cannot prove a structure is incidental, leave it.
- **Exhaustive in coverage, restrained in severity:** sweep the declared scope, but pure nits, style, and personal preference are OUT/omitted; judgment calls need concrete maintenance risk. Never inflate trivia into a blocking finding.
- **Planning-only by default:** produce scoped plans, risks, validation, and follow-up questions; leave implementation to the build workflow.

## Scope 1 — DESLOP (behavior- AND boundary-preserving simplification)

*Observable behavior* = return values, exceptions (type+message), side effects, emitted text (logs/stdout other code may parse), ordering, rounding, **and time/space complexity class**; a consumer relying on any of these must not be able to tell. **Allowed transforms — CLOSED list** (anything not on it is OUT of deslop — file a boundary-change follow-up):

- remove dead/unreachable code
- remove a literal/near-literal duplicate where a canonical copy exists in-reach (cross-unit dedup is OUT)
- inline a private, single-call-site pass-through wrapper that only forwards
- remove speculative/unused generality (params/config/extension points with no current consumer)
- remove vestigial leftovers (commented-out code, dead flags, shims for removed features)
- flatten **provably-equivalent** local control flow (nested-if → guard, collapse identical branches)
- replace hand-rolled code with an existing helper/stdlib at the same call site with identical contract

**Gate sequence:** apply the [DESLOP gates](reference/gates.md#deslop-gate-sequence) per candidate. Survives all five ⇒ in-scope. Behavior-touching simplification stays **HITL + requires characterization tests**. **Firewall:** *simplify inside the unit; never move a seam — only via the allowed transforms, each proven unobservable within a declared blast radius.*

## Scope 2 — DESTALE (remove or correct stale/inaccurate items)

Apply the [DESTALE gate sequence](reference/gates.md#destale-gate-sequence) to code, docs, config, deps, CI, and examples. A **single mechanical source of truth** must prove drift and the correction; Candidate Evidence names that source and shows the stale → correct value pair.

## Out of scope — handoffs (each carries a fallback)

- boundary-moving restructuring (split mixed-responsibility files, move responsibilities, change APIs/layers, cross-unit dedup) → file a boundary-change follow-up issue
- tracker/backlog hygiene (stale issues, labels, untriaged backlog) → follow the repo tracker workflow
- unsafe-default / security assessment → `security-review`, flag-and-refer only *(built-in)*
- terminology / ADR / glossary → edit `CONTEXT.md`/ADRs manually

## Quick start

1. Default to a repo-wide sweep when scope is unspecified; honor any explicit narrower user scope — **narrower scope** means path-limited, docs-only, config-only, dependency hygiene, or a specific concern.
2. Resolve invoked repo root and cleanliness with read-only commands (`git rev-parse --show-toplevel`, `git status --porcelain`); call out dirty-worktree noise. Read its rulebook and confirmed profile's Agent Setup Doc paths, gate/domain/ADR refs and README/CONTRIBUTING. Missing/stale setup prompts owner invocation; no default installation paths or automatic setup. Tracker reads/publication use `/forge` in only the required verified scopes.
3. Use read-only discovery subagents: fan out for repo-wide coverage; use enough passes for explicit narrower scope. This is the default posture for discovery. If coverage is incomplete, label the run partial, list uninspected surfaces and known gaps before findings, and make no absence-of-debt claims.
4. Discover ecosystems from manifests/config/CI, then build the deslop and destale candidate list by applying the applicable gate sequence with recorded proof and negative checks.

   **Complete when:** every candidate has a gate verdict and every unproven lead is a known gap or `N/A — <why>`.
5. Present the proposal; ask which slices to approve, defer, merge, split, or discard.
6. After approval, measure each slice's numeric and emptiness criteria against the [measurable acceptance criteria](#measurable-acceptance-criteria) rules, then route to `/plan-to-issues`; implementation goes to the build workflow.

## Classification rules

- **AFK** — mechanical, reversible, scoped, all proof gates satisfied, acceptance criteria clear, no behavior/domain/ownership uncertainty; normal review remains mandatory.
- **HITL** — behavior-touching deslop (characterization tests required).
- **Needs info** — the fail-closed classification for a concrete lead with named missing proof/source/owner/check gate; it is not a finding until resolved. Missing owner proof or missing impact proof has exactly one outcome: `Needs info`; neither can be HITL or AFK.

## Planning rules

- Prefer small surgical slices with independent review; separate pure docs, mechanical destale, dependency upgrades, and behavior-touching deslop unless coupling is proven, sequencing characterization tests first.
- Preserve generated files unless the generator/source of truth is known. Discovery mode never deletes, rewrites history, mass-formats, changes locks, or upgrades dependencies.
- Write each slice with the [candidate template](reference/candidate-template.md).

### Measurable acceptance criteria

A published candidate's criteria **MUST** be checkable before a builder starts; measure them here, not after delivery.

- **Derive or declare.** A byte budget **MUST** be computed from the enumerated cut list, or state which additional content the implementer is authorized to remove. A target unreachable from the issue's own enumerated changes is a defect in the issue.
- **Subtract mandated content first.** Where an issue both mandates content (an index, a retained table, a byte-frozen file) and sets a budget on the file holding it, **MUST** check the budget against the mandated content's own measured size before publishing.
- **Scope every emptiness assertion.** A "grep must return empty" criterion **MUST** state its search scope and whether ignore entries, fixtures, and negative assertions count, and **MUST NOT** be satisfiable only by deleting a fail-closed guard. Count-of-files figures **MUST** name their glob: `tests/*.sh` means different things to a shell glob and a git pathspec.

## Output shape

1. **Scope inspected** — paths, docs, commands, known gaps before findings, and complete/partial coverage.
2. **Top findings** — ranked table of proven deslop/destale candidates only.
3. **Needs info / known gaps** — partial coverage, failed fan-out, concrete leads missing proof, and the exact question/source needed.
4. **Recommended plan** — ordered slices with type, risk, validation, and dependencies.
5. **Handoffs** — routed items, each with its fallback.
6. **Next step** — approve slices, convert to issues, or widen/re-scope discovery.
