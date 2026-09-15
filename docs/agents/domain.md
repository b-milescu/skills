# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

This repo uses a **single-context** layout: one root `CONTEXT.md` plus `docs/adr/` when present.

Use this file as `project_profile.domain_docs` for this repo. It records the
context and ADR layout that project-profile hooks should cite when workflow
agents need domain language.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root.
- **`docs/adr/`**, when present — read ADRs that touch the area you're about to work in.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap. Record the gap in the relevant project docs manually.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (some decision) — but worth reopening because…_
