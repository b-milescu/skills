# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

Run the local gate with Node.js 22.x, matching `.nvmrc`, `package.json` `engines.node`, and the GitLab CI `node:22` image. `npm run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which runs:

**Fresh checkout or worktree bootstrap:** A fresh checkout or new worktree must bootstrap before running the gate. Switch to Node 22 per `.nvmrc` (e.g. `nvm use 22`), then run `npm ci` to install dependencies from `package-lock.json`, then run `npm run check`. Skipping either bootstrap step produces spurious failures (wrong Node version or missing `node_modules`).

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

This repo's Check Gate facts are verified against `setup-dev-skills/reference/project-profile-facts.json`: `gate_policy_ref`, `ci_jobs.ref`, `manual_validation_rules.ref`, command, runtime, and required CI jobs.

Project-profile hooks may specialize project policy, but they must not weaken
reviewed-SHA binding, exact-SHA CI, explicit authority source, independent
review, the child-builder boundary, the verifier read-only boundary, or
MCP-first transport correctness plus help-first `glab` fallback correctness.

## Gate coverage for ready handoff

This repo's default `Gate coverage` is `full-local` when `npm run check` passes
on the exact MR head SHA. Required CI mapping:

| Required CI job | Local coverage | Notes |
| --- | --- | --- |
| `check` | `npm run check` | CI adds `npm ci` first, then runs the same canonical local Check Gate. Dependency-install failures are CI evidence, not a separate local gate command. |

`Gate coverage rationale` should cite this section and
[`CI parity`](#ci-parity): required CI jobs = `check`; locally covered jobs =
`check`; unmapped CI-only jobs = `none`. If a future MR changes CI so required
jobs are no longer locally covered, classify that MR as `hybrid` or `ci-only`
and wait for exact-SHA CI success, or record an authorized CI waiver, before
ready/review handoff.

## Executable-bit policy

Only these tracked entrypoints keep executable bits: `install.sh`;
`scripts/check.sh` (via `npm run check`). Legacy `gitlab/scripts/*.sh`
helpers stay non-executable compatibility artifacts; invoke them with
`bash ...` only when a documented fallback explicitly still needs one.
Shell, Node, and regression helpers stay non-executable (`100644`).

## Targeted checks

These are the **non-test** operator commands worth running on their own: the gate's
canonical entrypoints plus ad-hoc install smokes and inspection commands. Per-test
rows are intentionally not duplicated here — the [Shipped shell regression
inventory](#shipped-shell-regression-inventory) below is the single source of truth
for every `tests/*.sh` script, and `npm run check` runs them all.

| Area | Command | Notes |
| --- | --- | --- |
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | Read-only check for Claude/OMP agent variant parity (including omp-only drift), canonical workflow / `gitlab` pointer drift, Reviewer Lift / Review Report prompt drift, and missing required external skills such as `tdd` in installed agent runtimes. Set `AGENT_SKILLS_CHECK_HOME=<temp-home>` to inspect a disposable HOME. |
| Agent schema validation | `npm run check:agents-schema` | Validates Claude/OMP agent frontmatter parsing, required fields, name/filename matches, runtime-only field drift, retired bridge wording in Claude/OMP bodies, dialect-specific tool names, OMP MCP tool inventory, and canonical OMP multiword keys. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.omp/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.omp/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near or under **100 lines** when practical; split distinct or advanced content into one-level references, and check triggers, examples, and reference depth. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs every top-level `tests/*.sh` file. Keep this inventory synchronized when adding, removing, or renaming a shell regression script.

| Script | Focus |
| --- | --- |
| `tests/agent-check.sh` | `agents/check.sh` parity, canonical-pointer coverage for generic and routed MR agents, prompt-drift, external-skill dependency, and no-mutation `install.sh --check` regressions under temporary homes. |
| `tests/agent-handoff-templates.sh` | Builder/reviewer machine-readable final handoff template field order, YAML parsing, synthetic example URL safety, and reviewer final-handoff procedure/prompt requirements. |
| `tests/agents-schema.sh` | Claude/OMP agent frontmatter parsing, required fields, name/filename matching, runtime-only field drift, dialect-specific tool casing, OMP MCP inventory, retired Pi fields/bridge wording, OMP model-provider allowlist, OMP thinking-level values, canonical OMP multiword keys, and model-token-free route names. |
| `tests/authority-verification-schema.sh` | Canonical `gitlab/reference/authority-verification.md` and `.schema.json` own approval/merge authority claim shape, source precedence, conflict/restricted/missing-source outputs, proceed/handoff/ask-human routing, builder/self-approval/self-merge blocks, and separate authority-vs-transport evidence references from Reviewer Lift, Review Report, delivery handoffs, finish result schema, authority matrix, Mutation Guard, and identity docs. |
| `tests/builder-prompt-dedupe.sh` | Claude/OMP builder prompts keep the canonical `start-build` pointer block, reject re-inlined Issue-pickup / Decoupling / Multiple-issue-worktree procedures, stay below the builder-sized body cap, and preserve anti-fabrication and child-mode authority invariants. |
| `tests/check-gate-inventory.sh` | Check Gate shipped shell regression inventory stays synchronized with tracked `tests/*.sh` files. |
| `tests/closes-keyword-lint.sh` | Pure-local `validate_closes_keyword` GitLab auto-close keyword shape linter (issue #295): reads an MR description (file/stdin) plus a target issue iid and exits 0 only when a plain `<closing-keyword> #<iid>` (the default `default_issue_closing_pattern` keyword set, case-insensitive) is present outside inline code spans and fenced code blocks and not only in a bolded/wrapped form; proves plain `Closes #N` passes (stdin + file), `**Closes:** #N`-only and `` `Closes #N` ``-only and missing cases fail closed, a plain reference co-existing with unrelated prose/fenced backticks passes, wrong-iid (incl. `#2950` for `#295`) and non-closing keywords do not match, usage/argument errors fail closed, and the helper makes no network call. |
| `tests/executable-bit-policy.sh` | Executable-bit policy enforcement: reads `git ls-files -s` index modes (not filesystem perms) and fails closed when any tracked `100755` file falls outside the documented allowlist (`install.sh`, `scripts/check.sh`); fixture self-tests prove a stray executable test, a non-allowlisted top-level script, and an executable `gitlab/scripts/*.sh` helper all FAIL while the two documented entrypoints PASS. |
| `tests/cleanup-codebase-invariants.sh` | `cleanup-codebase/SKILL.md` post-#149 identity: planning-only default, deslop + destale scopes, CLOSED allowed-transform list, five-gate deslop firewall, broad-sweep-by-default subagent fan-out (narrow on explicit request), and OUT-of-scope handoffs with fallbacks. |
| `tests/finish-result-schema.sh` | `gitlab/reference/finish-result-schema.json` carries every `finish_result` field/enum from #195 plus #210 transport evidence (`transport=mcp/glab-fallback/n/a`, reported as `via=mcp` / `via=glab-fallback`): result/action/sha/blocker incl. `identity_*`/`description_lost`/`cleanup_failed`, ci_guard, issue_state, worktree/branch cleanup, authority + caller-id verification sources, cleanup_verified/cleanup_failure_reason, override_recorded, conflict_type, retry_count; `gitlab/scripts/validate-finish-result.sh` (pure-local, no network) validates the success/handoff/each-blocker examples and the file/stdin valid object, and fails closed on malformed JSON, bad enum on every enumerated field, missing required field, unknown extra field, wrong type, negative retry_count, and bad sha pattern. |
| `tests/gitlab-content-guard.sh` | Shared `validate_gitlab_text` content-byte adapter: rejects crafted NUL body (plus non-whitespace C0 control and DEL) non-zero exit role + byte-offset diagnostic never leaks body, accepts clean Markdown body (backticks, `$vars`, tab, newline, CR) over both MCP-body-style stdin `--file`, asserts guard makes no network call. |
| `tests/gitlab-finish-authority.sh` | Deterministic `gitlab/scripts/gitlab-finish-authority.sh` role × merge-authority × action gate: builder-always-handoff, `invalid_user_id` on empty ids, `authority_source_mismatch`, reviewer/parent/human merge and queue-auto-merge allowances, same GitLab caller/author ids allowed for fresh gate-eligible reviewers, approval-only/human-release stops, no network call, and a matrix-match probe asserting the gate agrees with `gitlab/reference/authority-matrix.md` cell-for-cell. |
| `tests/gitlab-ci-finish-guards.sh` | `ci-watch-sha-pinned` and `finish-mr-authority-aware` specialize the shared GitLab Mutation Guard instead of restating a second full sequence; preserves per-poll MR head re-read, exact-SHA CI, no `ci status --mr`, first-class MCP gap tokens, exactly-one-finish-action, builder handoff, fetch-after-finish, worktree cleanup precondition, `closure_pending`, canonical policy pointers, and compact SKILL.md helper links. |
| `tests/gitlab-mcp-first-workflows.sh` | GitLab workflow docs/prompts stay MCP-first for GitLab API actions, preserve stable `/gitlab` snippet names, allow `glab` only as documented fallback/helper/troubleshooting/test coverage, require per-snippet transport contracts, preserve safe-text/content-byte rules for MCP bodies, and record known MCP merge/list gaps. |
| `tests/gitlab-mutation-guard.sh` | `gitlab/reference/mutation-guard.md` and `mutation-guard.schema.json` define the canonical GitLab Mutation Guard seam with ordered steps, blocker/gap/transport evidence tokens, fallback-forbidden states, first-class MCP gap states (`mcp_unavailable`, `mcp_merge_robustness_gap`, `mcp_pagination_gap`), examples for stale head, stale/red CI, missing authority, self-merge risk, merge robustness fallback, successful post-mutation re-read classification, and cross-project `skill://gitlab/...` guard resource guidance. |
| `tests/gitlab-snippet-metadata.sh` | `gitlab/reference/snippet-metadata.json` remains the machine-readable source of truth for all 20 stable GitLab workflow snippets; verifies required metadata fields, unchanged snippet names, `skill://gitlab/reference/...` resource references, via evidence tokens, and exact sync between the Markdown transport table and metadata. |
| `tests/gitlab-delivery-schema.sh` | Canonical shared GitLab `delivery.kind=gitlab-delivery` schema field order, approved generated-copy drift in builder/reviewer handoff templates, GitLab noun preservation, evidence taxonomy, `not_run_reason`, authority/action/blocker enums, and next-action tokens. |
| `tests/gitlab-help-cache.sh` | `/gitlab` help-first run-dir cache guidance, context invalidation, and verification-status wording. |
| `tests/gitlab-build-cards.sh` | Build-focused `/gitlab` command cards stay pointer-based, cover builder read/action snippets, exclude finish/approve/merge snippets (least-privilege), and remain linked from `/start-build`. |
| `tests/gitlab-review-cards.sh` | Review-focused `/gitlab` command cards stay pointer-based, cover review read/action/CI snippets, and remain linked from `/start-review`. |
| `tests/gitlab-split-snippets.sh` | GitLab workflow snippets remain split into Draft MR create, MR description update, Draft MR mark-ready, SHA-bound approval, merge, auto-merge, MR-note, issue-note, label-reconcile, safe-mr-json, auto-merge-api-fallback, CI watch, and finish MCP tool guidance. |
| `tests/gitlab-workflow-helpers.sh` | `get_merge_request_workflow_snapshot`, `gitlab/scripts/gitlab-merge-watch.sh`, `finish_merge_request`, `get_post_merge_snapshot`, and `MCP safe GitLab text tools` SHA/CI/authority guard, control-char-safe SHA-pinned merge-completion watch over `get_merge_request_workflow_snapshot` (merged / ci-failed / head-drift / control-char blocked / timeout terminals), local default fast-forward / merged-SHA cleanup safety, post-merge snapshot read-only reporting, MR description create/update and note wrapper delegation to the shared content guard plus file-backed control-character rejection, label reconciliation, safe MR JSON, and auto-merge API fallback behavior with fake GitLab/Git helpers. |
| `tests/install-external-deps.sh` | `install.sh` warnings for missing required/optional external skills and silence when dependencies exist under a temporary `HOME`. |
| `tests/install-symlink-ownership.sh` | `install.sh` preserves out-of-repo symlinks, replaces stale in-repo symlinks, and keeps shared routed MR agents installed in each runtime dialect without treating model pins as route names — all under temporary `HOME`. |
| `tests/installer-smoke-requirement.sh` | Installer smoke requirement docs stay present in `docs/agents/check-gate.md`: `install_surface` surface, `agents/`, `install.sh`, runtime routing triggers, temp-HOME installer smoke evidence, parent-owned gate evidence requirement, shared MR route symlink ownership in `install-symlink-ownership` inventory entry, `installer-smoke-requirement` self-entry. |
| `tests/issue-delivery-loop-invariants.sh` | `issue-delivery-loop/SKILL.md`, Dev Workflow docs, `start-build/reference/parent-orchestrator.md` preserve post-#151 pointer shape plus #226 skill-only tier routing, #227 runtime-aware reviewer split, #300 routed-only cutover, and #301 model-free shared-route cutover: classify trivial/moderate/high-risk before child launch, launch exact model-free routed builders/reviewer (`mr-builder-trivial`, `mr-builder-moderate`, `mr-builder-high-risk`, `mr-reviewer-final`) from the current dialect directory (`agents/claude/<route>.md` or `agents/omp/<route>.md`); Model pins live in frontmatter instead of route names, and provider pins live there too; distinguish route basenames from `child mr-builder`/`mr-reviewer` mode labels; no review scout/no generic fallback/no shim/no cross-runtime substitute; missing route stays route-unavailable blocker. Adds #249 single-table-owner split: per-tier builder route names live only in `parent-orchestrator.md` (positive presence), banned three pointer files' doc surface (negative `refute`), while independent-review floor sentences stay present in four files. Adds #274 wide-surface test-refactor routing rule: both criteria owners carry trivial-path exclusion broad multi-file / shared-harness test refactors plus objective blast-radius signal (`>=10` test files) routing class at least `moderate`. |
| `tests/parent-owned-gate-invariants.sh` | Canonical `start-build/reference/parent-owned-gate.md` seam owns parent-owned Check Gate / Gate Receipt fields, receipt schema, parent verification checklist, evidence-ready tokens, cross-project `skill://start-build/...` resource guidance, and references from builder, parent, reviewer, delivery-loop, and template docs. |
| `tests/md-links.sh` | Markdown local-link checker diagnostics for broken files, anchors, image targets, allowed skill URIs, and external URL host allowlist behavior. |
| `tests/retro-invariants.sh` | `retro/SKILL.md` secret/session-dump/redact safety tokens, the proposal-only / route-out boundary (never edits canonical skills/docs/tests directly, routes approved candidates out via `/gitlab-to-issues`), the safety-floor guard (floor-touching proposals classified `human-decision`), and the #256 lookback-scope tokens (scope names, graceful degradation, no-overfit rule). |
| `tests/parent-subagent-placement.sh` | Parent-only subagent discovery guidance stays in the parent-orchestrator recipe and out of child builder prompts. |
| `tests/omp-agent-loader-smoke.sh` | Temp-`HOME` `install.sh` exposes every `agents/omp/*.md` agent to the real OMP task-agent loader (`discoverAgents(...)` pointed at the temp runtime through `PI_CODING_AGENT_DIR`/`HOME`), asserting the shared `read,grep,glob,bash,edit,write,todo,irc` tool allowlist, the server-scoped `mcp__gitlab_mcp_*` / `mcp__wowtools_*` MCP wildcard selectors (rejecting bare/broad/Claude-style/old-exact MCP entries), `autoload-skills`, nonempty prompts, and routed model/thinking pins for every routed OMP agent; expected names derive from `agents/omp/*.md` and loader-absent runs report a clear N/A while still verifying installer exposure of all OMP agents. |
| `tests/post-merge-verifier-read-only.sh` | Canonical post-merge verifier recipe read-only invariant keeps the forbidden-action tokens (approve/merge/queue, force-close, delete-branch, release/deploy/operator), `issue_closure_pending` / `source_branch_cleanup_pending` report tokens, helper wiring, and removed top-level skill absence check, and keeps the post-#152 dropped "promised docs/ADR/follow-ups" check absent. |
| `tests/project-profile-hooks.sh` | `project_profile` extension fields stay documented in the GitLab delivery schema and generated handoff copies; setup-dev-skills seeds/generated docs declare gate, labels, branch naming, CI jobs, domain/ADR, release/deploy, manual validation, language, and auxiliary index hooks; GitLab-specific schema names and safety invariants remain intact. |
| `tests/project-profile-facts.sh` | `setup-dev-skills/reference/project-profile-facts.json` remains the canonical project-profile fact source for Agent Setup Doc paths, Triage Role-to-live-label mappings, Check Gate refs, Dev Workflow refs, branch naming, CI parity, skill resource URIs, and a non-default docs/labels fixture; setup seeds/live docs and GitLab issue pickup avoid globally hardcoded labels. |
| `tests/queued-auto-merge-default-finish.sh` | Default delivery/review finish stays queued auto-merge on pass + merge authority with review launched in parallel with CI for every tier: pins the canonical `## Default finish: queued auto-merge` wording, the exact-SHA CI floor ("pipeline must succeed", queue only on pending/running/success), and the fail-closed guard (failed/canceled reviewed-SHA pipeline blocks, not queues) across `start-review/REVIEW-FLOW.md`, `start-build/reference/parent-orchestrator.md`, `issue-delivery-loop/SKILL.md`, `start-build/reference/post-merge-verifier.md`, and `start-build/docs/effort-scaling.md`, and refutes the retired block-watch / trivial-tier terminal-green-wait instructions. |
| `tests/regression-harness.sh` | Shared regression harness self-check for shell assertion primitives, command-output capture, marked-section extraction, schema-sync field extraction, and fake GitLab fixture setup. |
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
| `tests/reviewer-prompt-dedupe.sh` | Claude/OMP reviewer prompts remain pointer-based below the duplication threshold while preserving critical runtime invariants, and shared ADR template ownership/drift stays enforced. |
| `tests/reviewer-lift-lint.sh` | Pure-local `validate_reviewer_lift` Reviewer Lift presence + closed-set value linter: the required-row list it enforces is extracted from `start-build/templates/reviewer-lift-schema.md` (no invented/dropped rows); a full Lift block passes via stdin, file, and embedded-in-prose; removing each of the 20 required rows one at a time fails closed with a diagnostic naming the missing row; closed-set rows (`Merge authority`, `Review gate`, `Gate owner`, `Gate coverage`, `Touched safety surfaces` against the fixed safety-surface vocabulary including `wire-protocol` with `other` catch-all, and `Acceptance surfaces` tokens read at runtime from the `acceptance_surfaces_ref` vocabulary) accept allowed values and fail closed (exit 4) on an out-of-set value naming the offending row; empty/no-table input fails closed; and the helper makes no network call. |
| `tests/reviewer-lift-schema.sh` | Reviewer Lift generated-copy blocks match the canonical schema and stale duplicate field-list tables are rejected. |
| `tests/runtime-shared-resources.sh` | Installed skills expose shared docs/templates through skill-local `docs/` and `shared-templates/` resource symlinks from a foreign project cwd, including the Agent Readiness scorecard; runtime skill roots do not expose `docs`/`templates` as bogus skills; invoked agent prompts and workflow skill entrypoints use explicit `skill://<skill>/...` URIs for reusable skill-owned docs/templates/scripts while preserving target-rooted `docs/agents/...` policy references. |
| `tests/safety-floor-tokens.sh` | Per-site safety-floor token coverage across all 16 floor-carrying sites: pins exactly the "must not weaken" litany tokens present at HEAD per site (uneven by design — `parent-orchestrator.md` and `issue-delivery-loop/SKILL.md` carry subsets), asserts per-site deliberate extras (`gitlab/SKILL.md` transport/record-naming floors; `parent-orchestrator.md` credentials/read-only/child-boundary floors), and cross-checks `start-build/docs/effort-scaling.md` §Hard floors so floor drift fails closed everywhere. |
| `tests/setup-dev-skills-guardrails.sh` | `setup-dev-skills` coding guardrails seed, generated pointer, and no upstream prose vendoring regressions. |
| `tests/setup-dev-skills-invocation.sh` | `setup-dev-skills` remains manual-invocation only and docs preserve ask-before-running guidance. |
| `tests/start-build-bypass-wording.sh` | `start-build` canonical human bypass protocol strict non-inferable accepted-phrase rule, ambiguous-release-language rejection, named-actor/reason/audit-trail requirements, and pointer-only `SAFETY.md` with builder self-approval guard intact. |
| `tests/start-build-child-path-size.sh` | `start-build` child-builder path size, child authority boundary, and parent-only discovery exclusion regressions. |
| `tests/start-build-context-read-matrix.sh` | `start-build` first-screen mode routing table and child avoid-list anchor regressions. |
| `tests/start-build-discovery-budget.sh` | `start-build` Discovery Budget, Build Plan Packet, bounce rule, authority boundaries, and template pointer regressions. |
| `tests/start-build-mode-cards.sh` | `start-build` compact mode cards for child-builder, parent-owned-gate, revision, and parent-orchestrator stay pointer-map-only, preserve fallback triggers and canonical safety anchors, link accepted `/gitlab` snippet names, and remain discoverable from `start-build/SKILL.md`. |
| `tests/start-build-secret-invariant.sh` | `start-build/SAFETY.md`, child-builder flow, and routed builder agents preserve credential/secret-handling tokens: never-paste-secrets, no printing token-bearing config, read-into-shell-variable-without-printing discipline, and redacted diagnostics before MR/CI log surfaces. |
| `tests/start-build-done-criteria.sh` | `start-build` done criteria stays mode-tiered (builder-ready / review-gate-complete / finish-merge / post-merge-verified) with reference-flow pointers, no builder self-approve/self-merge wording, and a mode-specific `SKILL.md` note. |
| `tests/start-build-ready-gate-push-semantics.sh` | `start-build` early Draft/implementation push phases, exact-SHA Gate coverage ready handoff (full-local vs hybrid/ci-only), parent-owned child no-pass/fail boundary, and Reviewer Lift local-gate/delta semantics stay synchronized. |
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
- Issue #53 agent schema validation requirements for Claude/OMP dialect-specific frontmatter and tool casing.
- `scripts/check.sh` canonical wrapper wiring those checks, Markdown checks, and regression scripts behind one stable command.
- Skill authoring guideline `SKILL.md` should stay near or under 100 lines where practical (`wc -l`); split distinct or advanced content into one-level references, and check triggers, examples, and reference depth.
- No `Makefile` exists at time of writing.

## CI parity

`.gitlab-ci.yml` mirrors the local Check Gate instead of re-encoding individual checks in CI:

- The repo-local runtime contract is Node.js 22.x (`.nvmrc` and `package.json` `engines.node`).
- GitLab CI uses the Node 22 image.
- Required GitLab CI job name: `check` (stage `validate`).
- The `check` job runs `npm ci` so dependencies come from `package-lock.json`.
- The `check` job then runs `npm run check`, the same canonical command used locally.
- Pipeline workflow rules create pipelines for merge requests, the default branch, and tags.
- CI caches npm's download cache under `.npm/`, keyed by `package-lock.json`; `npm ci` remains the correctness boundary, so cache misses only make installs slower.

Do not add CI-only validation here unless it is first added to `npm run check` and documented as part of the local Check Gate.

## Manual validation rules

Manual validation is supporting evidence only when automation cannot cover the
change. Record exact commands or observations, redact secrets, and bind the
evidence to the reviewed SHA. Manual validation does not replace `npm run check`
for ready-marking unless the MR records a specific, reviewed exception.

## Installer smoke requirement

When a change alters the **install surface** — the topology the installer actually materializes — declare `install_surface` in `Acceptance surfaces` and include installer smoke evidence. The install surface is the set of inputs that change what `./install.sh` links or exposes, not every file under `agents/`. A change is on the install surface when it touches any of:

- agent **frontmatter** that the installer or runtime routing reads: an agent's `name`, its routing identity (route filename / basename), or its `skills:` / `autoload-skills:` lists;
- `install.sh` itself, or the runtime agent routing / symlink topology it produces (which agent and skill symlinks exist, and where they point);
- adding, removing, renaming, or moving a tracked file under `agents/` (a new agent dialect file, a deleted route, a renamed skill), since that changes which symlinks the installer creates.

A change is **not** on the install surface — and does not by itself require installer smoke — when it edits only an agent file's prose **body** while leaving that file's frontmatter (`name`/routing/`skills:`/`autoload-skills:`), filename, and symlink topology byte-identical. A body-prose-only edit under `agents/` therefore does not trigger this requirement on its own.

This requirement cannot be satisfied by `npm run check:agents-schema` or `./install.sh --check` alone; an actual `./install.sh` run in a temp HOME confirms installer output behavior.

Required evidence: run `HOME=<tmpdir> ./install.sh` and verify that expected agent and skill symlinks exist and no unintended additions or removals occurred. Use a safe temp HOME to avoid mutating the live `$HOME`.

For parent-owned gate evidence, name `./install.sh` or a temp-HOME installer smoke as the expected confirmation when `install_surface` is present.

`tests/install-symlink-ownership.sh` regression covers symlink ownership including shared routed MR agents in both runtime dialects under `npm run check`. A live temp-HOME installer smoke supplements rather than replaces it.

**Session-cache caveat:** Agent definitions are loaded into a coordinator session's spawn inventory at session start. In-session spawn checks therefore reflect pre-change frontmatter after a merge; a live smoke of changed agent definitions using the same session will see the cached (pre-merge) state and is inconclusive by design. Live smoke of changed agent definitions requires a fresh session — record this as an operator step after each merge that touches agent frontmatter or routing.

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
