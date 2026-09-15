# Domain Docs

How dev skills consume the target repo's domain documentation.

Use this file, or the target-specific replacement path recorded in
`setup-dev-skills/reference/project-profile-facts.json`, as the default
`project_profile.domain_docs` reference. Record the repo's context and ADR layout
here so project-specific hooks can point agents at the right domain language
without renaming delivery fields or weakening safety invariants.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check context-scoped `docs/adr/` directories.

If any of these files don't exist, proceed silently. Don't flag their absence or suggest creating them upfront. Update `CONTEXT.md` and `docs/adr/` manually when needed.

## File structure

A single-context repo keeps `CONTEXT.md` and `docs/adr/` at the root. A
multi-context repo keeps root `CONTEXT-MAP.md` plus root `docs/adr/` for
system-wide decisions, and one `CONTEXT.md` with its own `docs/adr/` per context
directory (for example `src/ordering/` and `src/billing/`).

## Use glossary vocabulary

When your output names a domain concept in an issue title, refactor proposal, hypothesis, or test name, use the term as defined in `CONTEXT.md`; don't drift to synonyms the glossary explicitly avoids. If the concept isn't in the glossary yet, either reconsider the language or record the gap in the relevant project docs manually.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly instead of silently overriding it:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because ..._
