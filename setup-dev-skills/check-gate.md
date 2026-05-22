# Check Gate

Local commands agents should run before claiming a change is ready.

## Full local gate

Run the repo's full local gate before marking work ready:

```bash
<command>
```

Expected result: exit code `0`.

If no full local gate exists, write:

> No full local gate discovered. Use the targeted checks below and rely on CI for the remaining coverage.

## Targeted checks

Use the smallest relevant checks during development, then run the full local gate before review.

| Area | Command | Notes |
| --- | --- | --- |
| Tests | `<command>` | `<when to use>` |
| Lint / format | `<command>` | `<when to use>` |
| Typecheck / compile | `<command>` | `<when to use>` |
| Docs / generated files | `<command>` | `<when to use>` |

## Discovery notes

Record where these commands came from: `README.md`, `CONTRIBUTING.md`, `Makefile`, `package.json`, language project files, CI config, or local scripts.

## CI parity

Describe which CI jobs the local gate mirrors. If CI has jobs that cannot run locally, name them and explain why.

## When the gate cannot be run

If a command is missing dependencies, requires unavailable services, or is OS-specific, say so in the MR and include the best targeted evidence available. Do not claim `PASS` for a gate that did not run.
