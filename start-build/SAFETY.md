# Start Build Safety Rules

These rules protect safety boundaries while implementing GitLab issues. Project-specific rulebooks override this file when stricter. Domain-specific terms here (venues, sizing, breakers, post-fill, etc.) are examples; map them to the host project's equivalent safety surfaces. "External systems" below means product/runtime/operator systems, not the GitLab issue/MR actions explicitly prescribed by the build/review workflow.

## Non-negotiables

Violations must be fixed or explicitly accepted/waived in the MR before approval. SKILL.md's Essential safety summary owns the entry-level rules (external mutations, credentials, adapters, scope, behavior-change tests, TDD); the bullets below add detail not in SKILL.md.

- **Credential operational detail.** Beyond "never touch credentials": don't read, print, edit, commit, or summarize secret stores; don't log API keys, auth headers, or sensitive payloads; never paste secrets into MR descriptions, comments, CI logs, or screenshots.
- **Stay inside the approved domain envelope.** No new venues, scopes, capabilities, or rule changes unless a human approved it and the rulebook/docs changed.
- **Don't relax safety gates casually.** Removing guard errors, weakening dry-run/observe semantics, or enabling enforce/production paths must be explicit in the issue/MR with tests and reviewer-accepted rationale.
- **Preserve protective sequencing.** Multi-step flows that protect invariants keep their full sequence and never leave the system unprotected without escalation.
- **Mutations require the project's coordination primitive.** Any path that mutates shared/external state must acquire and verify the lease/lock; never force-steal an active one.
- **Immutable baselines stay immutable.** Fields set at entry that downstream math depends on are never overwritten; monotonic invariants only move in the safe direction.
- **Use the right numeric type for the domain.** Money/quantity/domain math uses exact decimal types; floats only at I/O boundaries before conversion.
- **Pure engines stay pure.** Deterministic rule modules don't read files, call APIs/DB, or use wall-clock time internally.
- **State changes go through typed/atomic paths.** Use the project's repository/transaction abstractions, not ad-hoc writes. Required state fields fail loud; never coerce missing critical values to defaults.
- **Migrations are append-only.** Never edit a migration that may have run outside a throwaway DB. Add a new numbered migration and test it.
- **Behavior-touching refactors require regression evidence.** See below.
- **Project's full check gate green before requesting review.** Run the gate locally (lint, format, typecheck, full test suite, shellcheck/etc as the project defines) before pushing. Once the local gate is green and the branch is pushed, mark the MR ready immediately — do not block ready-marking on CI; CI is the reviewer's clean-checkout safety net, not a builder-side wait. Wait for CI before ready only when the local gate could not be run (missing tooling, OS-specific job, unreachable integration suite) or when the change touches CI infrastructure itself; in those cases, say so in the MR. Record CI pipeline URL/ID/status/SHA when available so reviewers can detect stale green CI.

## Behavior-touching refactors

A refactor is **behavior-touching** if it modifies external mutation paths, protective sequencing, lock TTL/ownership, gates/breakers, immutable baselines, schemas/migrations/persistence, daemon poll/health/heartbeat, slow-path scripts that produce mutations or intents, CLI stdout consumed by other code, or deploy/credential topology.

Ambiguous = behavior-touching. Behavior-touching refactors need regression evidence and reviewer attention.

Valid regression evidence includes:

- targeted automated tests;
- explanation of existing coverage naming tests and what surface they cover;
- manual dry-run only when automation is infeasible, with exact commands and no secrets.

## Quality rules

- No broad catch-alls without a recovery comment and an observable signal (metric, alert, return value, finding).
- No assertions for runtime validation outside tests; use explicit errors or schema validation.
- Prefer typed/domain-specific errors at library boundaries; CLIs translate to exit codes/messages.
- Keep stdout contracts stable when other code parses CLI output.
- Public modules/classes/functions get docstrings; safety invariants get why-comments at the seam.
- Avoid mutable globals for runtime state; inject dependencies (clocks, sleeps, clients) explicitly.
- Use UTC-aware timestamps; don't bypass timezone lints without a documented invariant.
- Logs help operators without exposing secrets.
- Health/heartbeat changes need fake-clock stale-state tests.

## Anti-patterns

- "Just one raw external call." Use adapters.
- "Observe-only initializes the executor, so it's fine." Verify no mutating methods are called.
- "This is only a refactor." Safety surfaces still need regression evidence.
- "Float is simpler." Not for money/domain math.
- "I'll broaden scope while here." Open a separate issue.
- "The test exercises the code." Tests need meaningful assertions.
- "Local fallback files can be committed for audit." No; local-only advisory.
- "I'll paste the failing log into the MR." Strip secrets first; redact tokens, headers, env values.

## Escalation

Stop and escalate by assigning/commenting/applying `needs-human` when there is external-system safety uncertainty, rule ambiguity, credential exposure, review disagreement after two rounds, or legal/ethical concern.

## Done criteria

A task is done when the MR has approval; CI/check gate is green, pending under protected auto-merge, or explicitly waived in writing; docs/runbooks are updated; no secrets were exposed; no live unintended product/runtime/operator side effects occurred; the MR is merged only when merge authority allows; the linked issue is closed by `Closes #<id>` or project workflow; any required durable summary is recorded.
