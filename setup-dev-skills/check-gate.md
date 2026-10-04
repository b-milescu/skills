# Check Gate

Local commands agents should run before claiming a change is ready.

## Full local gate

Run the repo's full local gate against the exact candidate before marking work ready:

```bash
<command>
```

Expected result: exit code `0`.

If no full local gate exists, record `N/A — no full local gate discovered` with
the best targeted checks and obtain project-owner confirmation.

## Project-profile refs

Use the target's confirmed `project_profile.gate_policy_ref` and its declared
advisory-CI and manual-validation references, preserving custom profiles and paths.
Shared field guidance supplies no target defaults. Record the exact local
gate/runtime/bootstrap, targeted checks, independently scoped advisory CI and
allowed manual evidence here.

Project-profile hooks may specialize project policy, but they must not weaken
the safety-floor litany (`start-build` skill, `SAFETY.md#safety-floors`).

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

## Advisory CI parity

Describe which configured CI jobs mirror the local gate. Record an observed
status only with its pipeline/job commit. Any CI status or absence — pending,
failed, canceled, skipped, missing, stale, wrong-commit, unavailable — is
advisory and never replaces the exact-candidate local gate or changes
eligibility derived from it.

## Manual validation rules

Document manual validation commands, dry-run rules, required screenshots/logs,
and redaction requirements when automation is unavailable. If manual validation
is not accepted evidence for this repo, write that explicitly.

## When the gate cannot be run

If a command is missing dependencies, requires unavailable services, or is OS-specific, say so in the change request and include the best targeted evidence available. Do not claim `PASS` for a gate that did not run.
