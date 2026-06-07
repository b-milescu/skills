# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

Run the local gate with Node.js 22.x, matching `.nvmrc`, `package.json` `engines.node`, and the GitLab CI `node:22` image. `npm run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which runs:

- `bash -n install.sh`
- `npm run check:agents-schema`
- `bash agents/check.sh`
- `npm run check:md`
- `npm run check:links`
- each `tests/*.sh` regression script

Use `Local gate: PASS — npm run check` in MR Review Packets when it passes.

## Project-profile refs

Use this file as the default `project_profile.gate_policy_ref`, `ci_jobs.ref`,
and `manual_validation_rules.ref` for this repo. The full local gate is
`npm run check`; the CI job requirements are in [CI parity](#ci-parity); manual
validation rules are in [Manual validation rules](#manual-validation-rules).

Project-profile hooks may specialize project policy, but they must not weaken
reviewed-SHA binding, exact-SHA CI, explicit authority source, independent
review, the child-builder boundary, the verifier read-only boundary, or
MCP-first transport correctness plus help-first `glab` fallback correctness.

## Executable-bit policy

Only directly invoked entrypoints keep executable bits: `install.sh`,
`scripts/check.sh` (via `npm run check`), and `gitlab-local/scripts/*.sh`
helper entrypoints documented for direct use. Shell or Node helpers and
regression scripts documented with `bash ...` or `node ...` stay non-executable
(`100644`).

## Targeted checks

These are the **non-test** operator commands worth running on their own: the gate's
canonical entrypoints plus ad-hoc install smokes and inspection commands. Per-test
rows are intentionally not duplicated here — the [Shipped shell regression
inventory](#shipped-shell-regression-inventory) below is the single source of truth
for every `tests/*.sh` script, and `npm run check` runs them all.

| Area | Command | Notes |
| --- | --- | --- |
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | Read-only check for Claude/pi agent variant parity (including pi-only drift), canonical workflow / `gitlab-local` pointer drift, Reviewer Lift / Review Report prompt drift, and missing required external skills such as `tdd` in installed agent runtimes. Set `AGENT_SKILLS_CHECK_HOME=<temp-home>` to inspect a disposable HOME. |
| Agent schema validation | `npm run check:agents-schema` | Validates Claude/pi agent frontmatter parsing, required fields, name/filename matches, runtime-only field drift, pi bridge wording in Claude bodies, and dialect-specific tool casing. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.pi/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.pi/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near the skill guideline of under 100 lines when practical. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs every `tests/*.sh` file. Keep this inventory synchronized when adding, removing, or renaming a shell regression script.

| Script | Focus |
| --- | --- |
| `tests/agent-check.sh` | `agents/check.sh` parity, canonical-pointer, prompt-drift, external-skill dependency, and no-mutation `install.sh --check` regressions under temporary homes. |
| `tests/agent-handoff-templates.sh` | Builder/reviewer machine-readable final handoff template field order, YAML parsing, synthetic example URL safety, and reviewer final-handoff procedure/prompt requirements. |
| `tests/agents-schema.sh` | Claude/pi agent frontmatter parsing, required fields, name/filename matching, runtime-only field drift, and dialect-specific tool casing. |
| `tests/builder-prompt-dedupe.sh` | Claude/pi builder prompts keep the canonical `start-build` pointer block, reject re-inlined Issue-pickup / Decoupling / Multiple-issue-worktree procedures, stay below the builder-sized body cap, and preserve anti-fabrication and child-mode authority invariants. |
| `tests/check-gate-inventory.sh` | Check Gate shipped shell regression inventory stays synchronized with tracked `tests/*.sh` files. |
| `tests/cleanup-housekeeping-invariants.sh` | `cleanup-housekeeping/SKILL.md` post-#149 identity: planning-only default, deslop + destale scopes, CLOSED allowed-transform list, five-gate deslop firewall, broad-sweep-by-default subagent fan-out (narrow on explicit request), and OUT-of-scope handoffs with fallbacks. |
| `tests/finish-result-schema.sh` | `gitlab-local/reference/finish-result-schema.json` carries every `finish_result` field/enum from #195 plus #210 transport evidence (`transport=mcp/glab-fallback/n/a`, reported as `via=mcp` / `via=glab-fallback`): result/action/sha/blocker incl. `identity_*`/`description_lost`/`cleanup_failed`, ci_guard, issue_state, worktree/branch cleanup, authority + caller-id verification sources, cleanup_verified/cleanup_failure_reason, override_recorded, conflict_type, retry_count; `gitlab-local/scripts/validate-finish-result.sh` (pure-local, no network) validates the success/handoff/each-blocker examples and the file/stdin valid object, and fails closed on malformed JSON, bad enum on every enumerated field, missing required field, unknown extra field, wrong type, negative retry_count, and bad sha pattern. |
| `tests/gitlab-content-guard.sh` | Standalone `gitlab-local/scripts/gitlab-content-guard.sh` content-byte guard: rejects a crafted NUL body (plus a non-whitespace C0 control and DEL) with non-zero exit and a role + byte-offset diagnostic that never leaks the body, accepts a clean Markdown body (backticks, `$vars`, tab, newline, CR) over both stdin and `--file`, and asserts the guard makes no network call. |
| `tests/gitlab-finish-authority.sh` | Deterministic `gitlab-local/scripts/gitlab-finish-authority.sh` role × merge-authority × action gate: builder-always-handoff, `invalid_user_id` on empty ids, `authority_source_mismatch`, reviewer/parent/human merge and queue-auto-merge allowances, same GitLab caller/author ids allowed for fresh gate-eligible reviewers, approval-only/human-release stops, no network call, and a matrix-match probe asserting the gate agrees with `gitlab-local/reference/authority-matrix.md` cell-for-cell. |
| `tests/gitlab-local-ci-finish-guards.sh` | `ci-watch-sha-pinned` and `finish-mr-authority-aware` mechanics relocate to `gitlab-local/reference/ci-finish-guards.md` (per-poll `mr view` re-read, no `ci status --mr`, `--sha` guard, exactly-one-finish-action, fetch-after-merge, `closure_pending`, 7 polling + 8 authority items preserved), each SKILL.md snippet keeps heading/Inputs/helper/scripts pointers and links the card, demoted policy points to `REVIEW-FLOW.md`/`SAFETY.md`, and SKILL.md stays under 409 lines. |
| `tests/gitlab-mcp-first-workflows.sh` | GitLab workflow docs/prompts stay MCP-first for GitLab API actions, preserve stable `/gitlab-local` snippet names, allow `glab` only as documented fallback/helper/troubleshooting/test coverage, require per-snippet transport contracts, preserve safe-text/content-byte rules for MCP bodies, and record known MCP merge/list gaps. |
| `tests/gitlab-delivery-schema.sh` | Canonical shared GitLab `delivery.kind=gitlab-delivery` schema field order, approved generated-copy drift in builder/reviewer handoff templates, GitLab noun preservation, evidence taxonomy, `not_run_reason`, authority/action/blocker enums, and next-action tokens. |
| `tests/gitlab-local-help-cache.sh` | `/gitlab-local` help-first run-dir cache guidance, context invalidation, and verification-status wording. |
| `tests/gitlab-local-review-cards.sh` | Review-focused `/gitlab-local` command cards stay pointer-based, cover review read/action/CI snippets, and remain linked from `/start-review`. |
| `tests/gitlab-local-split-snippets.sh` | GitLab workflow snippets remain split into Draft MR create, MR description update, Draft MR mark-ready, SHA-bound approval, merge, auto-merge, MR-note, issue-note, label-reconcile, safe-mr-json, auto-merge-api-fallback, CI watch, and finish helper guidance. |
| `tests/gitlab-workflow-helpers.sh` | `gitlab-local/scripts/gitlab-ci-watch.sh`, `gitlab-local/scripts/gitlab-finish-mr.sh`, `gitlab-local/scripts/gitlab-post-merge-snapshot.sh`, and `gitlab-local/scripts/gitlab-wrappers.sh` SHA/CI/authority guard, local default fast-forward / merged-SHA cleanup safety, post-merge snapshot read-only reporting, MR description create/update and note wrapper file-backed control-character rejection, label reconciliation, safe MR JSON, and auto-merge API fallback behavior with fake GitLab/Git helpers. |
| `tests/install-external-deps.sh` | `install.sh` warnings for missing required/optional external skills and silence when dependencies exist under a temporary `HOME`. |
| `tests/install-symlink-ownership.sh` | `install.sh` preserves out-of-repo symlinks and replaces stale in-repo symlinks under a temporary `HOME`. |
| `tests/issue-delivery-loop-invariants.sh` | `issue-delivery-loop/SKILL.md` post-#151 pointer shape: serial-by-default WIP=1 envelope, parent-orchestrator.md pointer for decoupling-before-parallel/spot-check/revision rounds with three-round limit deferred to standalone-gate, preserved authority boundaries, child-builder/reviewer delegation, per-batch metrics, and post-merge verifier recipe handoff. |
| `tests/parent-owned-gate-invariants.sh` | Parent-owned Gate Receipt contract stays wired through child-builder handoff guidance, parent exact-SHA ready-transition procedure, reviewer claim/source-pointer handling, GitLab delivery schema, builder final handoff gate ownership fields, and this check-gate inventory. |
| `tests/md-links.sh` | Markdown local-link checker diagnostics for broken files, anchors, image targets, allowed skill URIs, and external URL host allowlist behavior. |
| `tests/memory-retrospective-invariants.sh` | `memory-retrospective/SKILL.md` read-only stance, never-print-secrets / never-paste-session-dumps / redact safety tokens, and the post-#153 propose-only / route-out boundary (output proposals only, never edit skill surfaces directly, route approved candidates out). |
| `tests/parent-subagent-placement.sh` | Parent-only subagent discovery guidance stays in the parent-orchestrator recipe and out of child builder prompts. |
| `tests/post-merge-verifier-read-only.sh` | Canonical post-merge verifier recipe read-only invariant keeps the forbidden-action tokens (approve/merge/queue, force-close, delete-branch, release/deploy/operator), `issue_closure_pending` / `source_branch_cleanup_pending` report tokens, helper wiring, and removed top-level skill absence check, and keeps the post-#152 dropped "promised docs/ADR/follow-ups" check absent. |
| `tests/project-profile-hooks.sh` | `project_profile` extension fields stay documented in the GitLab delivery schema and generated handoff copies; setup-dev-skills seeds/generated docs declare gate, labels, branch naming, CI jobs, domain/ADR, release/deploy, manual validation, language, and auxiliary index hooks; GitLab-specific schema names and safety invariants remain intact. |
| `tests/review-authority-explicit.sh` | Reviewer workflow docs default approval after pass unless explicitly restricted, keep approval authority separate from merge authority, and prevent missing merge authority from defaulting to approval-only finish authority. |
| `tests/review-authority-provenance.sh` | Reviewer/build workflow docs require approval and merge authority provenance, precedence, stable repo policy references, and builder-claim-not-grant semantics. |
| `tests/review-blocked-verdict.sh` | Reviewer verdict/action split keeps `blocked` first-class, synchronizes Review Report/final handoff verdict and action-blocker enums, and routes non-code blockers through explicit action fields. |
| `tests/review-ci-oq-decision-tables.sh` | Reviewer CI and Open Question policy lives in one canonical decision-table section and reviewer-facing docs/prompts point to it. |
| `tests/review-context-policy.sh` | Context Firewall, Review Context Capsule, context tiers, parent launch prompt minimality, and Reviewer Lift map-not-truth semantics stay present. |
| `tests/review-one-mr-per-reviewer.sh` | One-MR-per-fresh-reviewer-session default, multiple-MR isolation/serialization limits, child reviewer boundaries, and no grouped approval wording stay present. |
| `tests/start-review-project-binding.sh` | Reviewer project binding records bound target fields, blocks wrong-project mismatches without explicit cross-repo choice, and forbids ambiguous bare-ID action guidance. |
| `tests/review-reject-non-mutating.sh` | Reviewer reject path reports, stops/escalates, and avoids unauthorized MR closure guidance. |
| `tests/review-partial-secret-fail-closed.sh` | Partial-review and suspected-secret fail-closed rules block approval, define triggers, redact reports, avoid payload copying, and expose final-handoff blocker tokens. |
| `tests/review-action-order.sh` | Reviewer report/action order keeps final snapshots before posting, SHA guards before actions, stale-head skip handling, and intended-vs-completed action wording. |
| `tests/review-sha-bound-checkout.sh` | Single-MR review checkout mode requires exact-SHA local execution, bans unsafe pull wording, and records checkout path/SHA evidence. |
| `tests/review-structural-sweep.sh` | `start-review/REVIEW-FLOW.md` diff-first, blast-radius-bounded `## Structural maintainability sweep` keeps the `<1000` -> `>1000` file-growth threshold SHAPE paired with its "compelling decomposition rationale" escape hatch and the MF-N/C-N decision rule, without ossifying a bare `1000`. |
| `tests/review-tone.sh` | Scoped `## Review tone` section keeps the demanding voice for `MF-N` findings, preserves the style-non-blocking guarantees, and keeps `REVIEW-FLOW.md`/`SKILL.md` free of vendored upstream URL/thermo prose. |
| `tests/review-report-summary-first.sh` | Review Report summary-first contract keeps review verdict, reviewed SHA, CI status/SHA, findings, local checks, action fields, report-link fields, concise core headings, and required evidence/OQ placeholder-clean requirements visible. |
| `tests/reviewer-prompt-dedupe.sh` | Claude/pi reviewer prompts remain pointer-based below the duplication threshold while preserving critical runtime invariants, and shared ADR template ownership/drift stays enforced. |
| `tests/reviewer-lift-schema.sh` | Reviewer Lift generated-copy blocks match the canonical schema and stale duplicate field-list tables are rejected. |
| `tests/runtime-shared-resources.sh` | Installed skills expose shared docs/templates through skill-local `docs/` and `shared-templates/` resource symlinks from a foreign project cwd, runtime skill roots do not expose `docs`/`templates` as bogus skills, installed agent prompts avoid cwd-relative shared-resource paths, and workflow docs use explicit `skill://<skill>/docs/...` URIs for shared Decoupling Contract / Effort Scaling reads while preserving repo-local `docs/agents/...` links. |
| `tests/setup-dev-skills-guardrails.sh` | `setup-dev-skills` coding guardrails seed, generated pointer, and no upstream prose vendoring regressions. |
| `tests/setup-dev-skills-invocation.sh` | `setup-dev-skills` remains manual-invocation only and docs preserve ask-before-running guidance. |
| `tests/start-build-bypass-wording.sh` | `start-build` canonical human bypass protocol strict non-inferable accepted-phrase rule, ambiguous-release-language rejection, named-actor/reason/audit-trail requirements, and pointer-only `SAFETY.md`/`BUILD-FLOW.md` with builder self-approval guard intact. |
| `tests/start-build-child-path-size.sh` | `start-build` child-builder path size, child authority boundary, and parent-only discovery exclusion regressions. |
| `tests/start-build-context-read-matrix.sh` | `start-build` first-screen mode routing table and child avoid-list anchor regressions. |
| `tests/start-build-discovery-budget.sh` | `start-build` Discovery Budget, Build Plan Packet, bounce rule, authority boundaries, and template pointer regressions. |
| `tests/start-build-mode-cards.sh` | `start-build` compact mode cards for child-builder, parent-owned-gate, revision, and parent-orchestrator stay pointer-map-only, preserve fallback triggers and canonical safety anchors, link accepted `/gitlab-local` snippet names, and remain discoverable from `start-build/SKILL.md` / `BUILD-FLOW.md`. |
| `tests/start-build-secret-invariant.sh` | Builder credential/secret-handling tokens survive: `start-build/SAFETY.md` never-paste-secrets and strip-secrets-from-logs tokens, and both `agents/*/mr-builder.md` never-touch/print/paste credential token. |
| `tests/start-build-done-criteria.sh` | `start-build` done criteria stays mode-tiered (builder-ready / review-gate-complete / finish-merge / post-merge-verified) with reference-flow pointers, no builder self-approve/self-merge wording, and a mode-specific `SKILL.md` note. |
| `tests/start-build-ready-gate-push-semantics.sh` | `start-build` early Draft/implementation push phases, ready-marking local gate boundary, and Reviewer Lift local-gate/delta semantics stay synchronized. |
| `tests/start-build-simplicity-bar.sh` | `start-build/SAFETY.md` within-diff simplicity bar, blast-radius firewall anchors, preserved scope anti-pattern, and `SAFETY.md`/`SKILL.md` no-vendoring regressions. |
| `tests/start-build-stale-reviewer-control.sh` | `start-build` stale reviewer control, status/activity observation, runtime interrupt/escalation, and no blind duplicate-reviewer retry regressions. |
| `tests/start-build-tdd-trigger-policy.sh` | `start-build` behavior-touching TDD trigger, exception rationale/no-fake-tests, and issue-driven no-extra-approval prompt regressions. |
| `tests/start-review-command-ownership.sh` | `/start-review` GitLab command ownership stays in review cards/snippets; reviewer-owned docs/prompts reject raw `glab` command copies. |
| `tests/start-review-mode-cards.sh` | `start-review` compact mode cards for single-MR review, request-changes rerun, finish-action, and blocked routing stay pointer-map-only, preserve fallback triggers and canonical review anchors, require final snapshots plus fresh SHA guards, and keep grouped actions / partial-review / secret-exposure blockers fail-closed. |

## Workflow regression coverage map

Issue #79 introduced the workflow guardrail scripts; they are all runnable through
`npm run check` because `scripts/check.sh` executes every `tests/*.sh` script. The
per-script focus for each guardrail lives in the [Shipped shell regression
inventory](#shipped-shell-regression-inventory) above, which is the single source of
truth for `tests/*.sh` coverage.

## Discovery notes

Commands were derived from:

- `README.md` install instructions.
- `install.sh` skill/agent symlink, read-only `--check`, and external dependency warning behavior.
- `agents/check.sh` source parity, prompt drift, and installed external skill dependency checks.
- Issue #53 agent schema validation requirements for Claude/pi dialect-specific frontmatter and tool casing.
- `scripts/check.sh` canonical wrapper wiring those checks, Markdown checks, and regression scripts behind one stable command.
- Skill authoring guideline that `SKILL.md` should stay under 100 lines where practical.
- No `Makefile` exists at time of writing.

## CI parity

`.gitlab-ci.yml` mirrors the local Check Gate instead of re-encoding individual checks in CI:

- The repo-local runtime contract is Node.js 22.x (`.nvmrc` and `package.json` `engines.node`).
- GitLab CI uses the Node 22 image.
- The validation job runs `npm ci` so dependencies come from `package-lock.json`.
- The validation job then runs `npm run check`, the same canonical command used locally.
- Pipeline workflow rules create pipelines for merge requests, the default branch, and tags.
- CI caches npm's download cache under `.npm/`, keyed by `package-lock.json`; `npm ci` remains the correctness boundary, so cache misses only make installs slower.

Do not add CI-only validation here unless it is first added to `npm run check` and documented as part of the local Check Gate.

## Manual validation rules

Manual validation is supporting evidence only when automation cannot cover the
change. Record exact commands or observations, redact secrets, and bind the
evidence to the reviewed SHA. Manual validation does not replace `npm run check`
for ready-marking unless the MR records a specific, reviewed exception.

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
