# Start Review Checklist

Use this checklist to evaluate GitLab Merge Requests against safety invariants and project rules. Domain-specific terms here (venues, sizing, post-fill, breakers, etc.) are illustrative examples; map them to the host project's equivalent safety surfaces. "External systems" means product/runtime/operator systems, not the GitLab issue/MR actions explicitly prescribed by the review workflow.

## Must-fix checks

Flag these as Must Fix unless the user/project explicitly waives them in the MR. Do not use MR author or shared GitLab PAT as separate approval blockers:

- **Scope creep.** Diff changes rules, external behavior, deploy topology, or unrelated modules outside the MR description.
- **Live product/runtime/operator external mutation during development/review** outside an explicitly approved operator task. GitLab review actions are allowed only as prescribed by this workflow and project rules.
- **Raw external API calls outside approved adapters.** New direct HTTP/SDK calls bypass central quirks and redaction.
- **Credential leakage.** Secret stores read/printed/committed, auth headers logged, secrets in MR description/comments/CI logs/snapshots, fallback files committed, unredacted sensitive payloads. Prefix findings with `[SECURITY]`; these block approval and may require credential rotation.
- **Domain envelope violation.** New venues, scopes, capabilities, or unapproved rule changes.
- **Safety gate weakened** without explicit issue/MR scope, tests, and reviewer-accepted rationale.
- **Protective sequencing broken.** Closing without cancel/classify, mishandling in-flight resolution, silent unprotected states, missing escalation/error routing.
- **Lock semantics broken.** Mutations without lease, force-stealing active lease, TTL/cap invariant weakened, ownership bypass.
- **Immutable baselines broken.** Initial-set fields mutated post-entry, or monotonic invariants reversed.
- **Wrong numeric type.** New float arithmetic in money/sizing/breaker/accounting paths.
- **Pure engines gain side effects.** Deterministic rule modules start reading state, calling APIs/DB, or using wall-clock internally.
- **State/persistence changes without validation and tests.** Missing typed model updates, non-atomic writes, edited migrations, untested migration, or cross-language interop break.
- **Missing/weak behavior tests** for behavior changes, including tests that mostly verify implementation shape instead of observable behavior.
- **Behavior-touching refactor without regression evidence.** Ambiguous = behavior-touching.
- **CI red/stale, or full check gate omitted without explanation.** Pending CI is acceptable only under the documented auto-merge policy: local gate PASS, pipeline belongs to the reviewed SHA when exposed, and GitLab merge checks enforce green CI before merge. Targeted evidence is acceptable only when clearly justified.

## Review depth by touched surface

| Surface | Must do |
|---|---|
| External mutation, protective sequencing, recovery | Trace call order; verify locking; check failure tests; ensure no live evidence. |
| Enforce/observe boundary, intent drains | Confirm gate; verify no mutation in observe; check TTL/deadline invariants. |
| Domain gates, sizing, post-fill, breakers, immutable baselines | Recompute examples; verify exact-decimal math and edge tests. |
| State schemas, migrations, event/intent stores, DB | Check migration safety, typed models, transactions, idempotency, tests. |
| Credentials, deploy/systemd/cron/worktree, startup guards | Check fail-shut behavior, no secret copy/leak, runbook accuracy. |
| Adapter quirks, notifications, health/heartbeat | Verify fake-HTTP tests and redaction; inspect mutation/security paths directly when touched. |
| Slow-path scripts producing intents or mutations | Trace entry/exit logic and calls made/not made. |
| Pure refactor with no behavior change claim | Verify claim; require regression evidence if ambiguous. |
| Tests, fixtures, docs syncing existing behavior | Check assertions and accuracy. |
| Typo/format/comments/docs-only no behavior | Read for accuracy; compact packet allowed. |
| Dependency bump | Check changelog/advisories; inspect runtime/security API changes when present. |

When ambiguous, inspect the changed surface directly. No special approval label is required, and absence/mismatch of labels never blocks approval by itself.

## Context to load

| Scope | Always load | Add as needed |
|---|---|---|
| Small docs/tests-only change | this skill, MR description, MR diff, report template | Direct changed docs/tests if not summarized in MR. |
| Normal code change | small scope + project rulebook, relevant source/tests | Architecture sections; routine/script docs; `start-build` for refactor-claim verification; `tdd` when behavior-test evidence is material. |
| Safety/ops/state/external surface touched | normal scope + strategy/setup/rulebook docs, architecture sections | Roadmap proposals, migrations README, deploy docs, prior MR reviews, exact source/tests. |

For revision rounds N≥2, load only the latest commit range and unresolved threads; preserve reference docs for touched surfaces. Don't overload simple reviews; don't under-load operational/state/external changes.

## Review categories

1. **Scope match** — only what the MR description says.
2. **Strategy/safety invariants** — domain rules, caps, sequencing, locks, observe/enforce gates, immutable baselines.
3. **Architecture boundaries** — adapters, pure engines, state seams, ownership boundaries.
4. **Correctness** — edge cases, recovery, idempotency, exact-decimal math, concurrency, timestamps.
5. **Tests/evidence** — meaningful public-interface assertions, TDD trace when claimed/applicable, no live product/runtime/operator external systems, regression evidence.
6. **External-API safety** — quirks centralized, idempotency keys, redaction, no raw calls.
7. **State/DB/migrations** — typed models, atomic writes, append-only migrations, transactional events.
8. **Observability/ops** — metrics, urgent vs routine routing, health, heartbeat, runbooks.
9. **Security/credentials** — secret handling, env, injection/subprocess, MR-content redaction.
10. **Engineering quality** — types, public surface, comments, maintainability, idiomatic style.

## Detailed checks

- **Sequencing:** cancel-before-replace, classify result by polling, treat in-flight resolution as the close, route errors to required escalation.
- **Locking:** mutations require ownership; no force-steal; TTL bounds preserved; reconcile-mutate respects ownership.
- **Idempotency:** deterministic keys for retries; duplicate-id recovery via lookup, not blind retry.
- **Adapters:** integration quirks stay centralized and tested; errors route without secrets.
- **State / cross-language interop:** required fields stay required; writes atomic; transactions roll back; schema changes update typed models, fixtures, docs, and validators.
- **Migrations:** numeric prefix and append-only; one transaction per file; idempotent where practical; tests for empty and already-applied DB.
- **Deploy/topology:** privileged daemon clone vs ephemeral routine clone remain separated; secrets only in privileged clone; least privilege; failure preserved for post-mortem.
- **Operations:** important transitions emit metrics/events/logs; urgent/routine/error routing correct; health fails stale/degraded rather than falsely green; runbooks match commands.
- **Security:** block secret content in git/logs/MR text/tests, raw auth headers logged, shell with untrusted strings, SQL concatenation for dynamic values, loose key permissions, secrets in ephemeral clones, unsafe endpoint defaults.

## Tests: strong vs weak

Apply `tdd` principles for behavior-touching MRs. A red-green trace is strong supporting evidence; absence of red-first proof alone is not a blocker unless project rules require strict TDD or the final tests/evidence are weak.

Strong evidence: reported RED command and expected failure followed by GREEN result; table-driven pure cases for gates; fake adapters or recorded HTTP, not live network; real temp dirs for git/lock/state; fake clocks/sleeps for orchestration; assert calls *not* made in observe/failure branches; assert exact CLI stdout JSON where consumed; cover success and failure for safety-critical recovery.

Weak evidence: tests merely import code, exercise happy paths without assertions, mock away the behavior being reviewed, or couple to private methods/internal collaborators so refactors break tests without behavior change.

## Engineering-quality classification

- **Blocker / Must Fix:** concrete hazard or waste — broad catch swallows critical failure, direct write bypasses repo abstraction, unsafe public mutation surface.
- **Evidence request:** measurable claim without proof — "faster", "safer retry", "no behavior change" on a safety surface.
- **Non-blocking suggestion / Consider:** preference or maintainability idea.

Do not escalate style preferences to Must Fix.

## When to run code

Default: review by reading + build-agent evidence + CI. Pull the branch (`glab mr checkout <id>`) and run code when behavior needs confirmation, tests look light, you suspect a bug, or migration/CLI/health behavior is easier to verify by execution. Do **not** run mutating product/runtime/operator commands. Record read-only commands in `Code I Ran`; include no secrets in output.

## Common failure modes

- Rubber-stamping CI; gates don't prove safety semantics, and stale green CI for an older SHA proves nothing about the reviewed SHA.
- Rejecting good behavior evidence solely because red-first trace is missing when strict TDD is not a project rule.
- Accepting implementation-coupled tests that pass while user/operator behavior can still break.
- Ignoring no-live-external evidence.
- Accepting "not behavior-changing" without proof.
- Treating slow-path scripts/routines as harmless docs even though they execute.
- Missing cross-language interop.
- Escalating style preferences to Must Fix.
- Letting shared GitLab username/PAT block a separate-LLM review.

## Final rule

Be concrete, preserve safety boundaries, and help the build agent reach approve-ready code without weakening the system.
