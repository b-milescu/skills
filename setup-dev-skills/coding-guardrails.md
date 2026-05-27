# Coding Guardrails

Repo-local defaults for agent implementation work. Project rulebooks, issues, ADRs, and explicit human instructions override this file when stricter.

## Think before coding

- State assumptions that affect scope, design, data, or safety.
- If requirements have multiple valid interpretations, ask or present options before editing.
- Name tradeoffs and prefer the simpler path when it still meets the goal.
- If something is unclear enough to change the result, stop and ask.

## Simplicity first

- Build only what was requested and accepted.
- Avoid speculative abstractions, configurability, or future-proofing.
- Do not add error handling for impossible states unless the project requires defensive checks.
- If the solution grows large, pause and simplify before continuing.

## Surgical changes

- Touch only files needed for the requested outcome.
- Match existing style, naming, and layout.
- Do not refactor adjacent code or reformat unrelated files.
- Remove unused imports, variables, helpers, or docs only when your change created the orphan.
- Mention unrelated cleanup opportunities instead of doing them silently.

## Goal-driven execution

- Convert the task into concrete success criteria before implementing.
- For bugs and behavior changes, prefer a reproducing test or check before the fix.
- Run targeted checks while working, then the documented full Check Gate before claiming ready.
- If a check cannot run, report why and provide the strongest safe evidence available.
