# Domain Docs

How dev skills consume the target repo's domain documentation.

Read the invoked target's confirmed `project_profile.domain_docs` reference for
its context/glossary and ADR layout. Resolve repo-relative references from the
confirmed target root and preserve custom roots. Installed aliases and shared
field guidance supply no target defaults. Record confirmed locations here
without weakening safety invariants. Missing/stale/conflicting policy bindings
require explicit owner setup/choice, not auto-running setup or creating absent
setup docs.

## Before exploring, read these

- Read glossary/context documents at the locations declared by that target policy.
- If it declares a context map, follow it to only topic-relevant scoped context documents.
- Read relevant ADRs from the declared system-wide and context-scoped locations.

If an optional context or ADR document is absent, proceed silently. Don't flag its absence or propose creating it solely because it is absent. When a domain change needs a manual glossary or ADR update, use the target-declared locations and policy.

## File structure

Illustrative layouts, not required roots: a single-context repo may keep root
`CONTEXT.md` and `docs/adr/`. A multi-context repo may keep root
`CONTEXT-MAP.md` plus root `docs/adr/` for system-wide decisions, and one
`CONTEXT.md` with its own `docs/adr/` per context directory (for example
`src/ordering/` and `src/billing/`). Actual reads and updates follow the
confirmed target layout, not these examples.

## Use glossary vocabulary

When your output names a domain concept in an issue title, refactor proposal, hypothesis, or test name, use the term defined in the applicable target glossary; don't drift to synonyms it explicitly avoids. If the concept isn't in the glossary yet, either reconsider the language or record the gap in the relevant target domain docs manually.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly instead of silently overriding it:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because ..._
