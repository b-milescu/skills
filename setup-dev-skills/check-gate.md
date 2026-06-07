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

## Project-profile refs

Use this file, or the target-specific replacement path recorded in
`setup-dev-skills/reference/project-profile-facts.json`, as the
`project_profile.gate_policy_ref`, `ci_jobs.ref`, and
`manual_validation_rules.ref`. Record the exact full local gate, targeted
checks, CI job requirements, and allowed manual validation evidence here.

Project-profile hooks may specialize project policy, but they must not weaken
reviewed-SHA binding, exact-SHA CI, explicit authority source, independent
review, the child-builder boundary, the verifier read-only boundary, or
MCP-first transport correctness plus help-first `glab` fallback correctness.

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

## CI job requirements

Describe which CI jobs the local gate mirrors. If CI has jobs that cannot run
locally, name them and explain why. Green CI counts only when the pipeline/job
SHA exactly matches the reviewed SHA.

## Manual validation rules

Document manual validation commands, dry-run rules, required screenshots/logs,
and redaction requirements when automation is unavailable. If manual validation
is not accepted evidence for this repo, write that explicitly.

## When the gate cannot be run

If a command is missing dependencies, requires unavailable services, or is OS-specific, say so in the MR and include the best targeted evidence available. Do not claim `PASS` for a gate that did not run.
