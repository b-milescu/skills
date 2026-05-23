# Domain Docs

How dev skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check context-scoped `docs/adr/` directories.

If any of these files don't exist, proceed silently. Don't flag their absence or suggest creating them upfront. If `/grill-with-docs` is installed, it can create them lazily when terms or decisions are resolved; otherwise update `CONTEXT.md` and `docs/adr/` manually when needed.

## File structure

Single-context repo:

```text
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

Multi-context repo:

```text
/
├── CONTEXT-MAP.md
├── docs/adr/                          # system-wide decisions
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  # context-specific decisions
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## Use glossary vocabulary

When your output names a domain concept in an issue title, refactor proposal, hypothesis, or test name, use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, either reconsider the language or note the gap. If `/grill-with-docs` is installed, use it to resolve the gap; otherwise record the gap in the relevant project docs manually.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly instead of silently overriding it:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because ..._
