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

## Executable-bit policy

Only directly invoked entrypoints keep executable bits: `install.sh`,
`scripts/check.sh` (via `npm run check`), and `gitlab-local/scripts/*.sh`
helper entrypoints documented for direct use. Shell or Node helpers and
regression scripts documented with `bash ...` or `node ...` stay non-executable
(`100644`).

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | Read-only check for Claude/pi agent variant parity (including pi-only drift), canonical workflow / `gitlab-local` pointer drift, Reviewer Lift / Review Report prompt drift, and missing required external skills such as `tdd` in installed agent runtimes. Set `AGENT_SKILLS_CHECK_HOME=<temp-home>` to inspect a disposable HOME. |
| Agent schema validation | `npm run check:agents-schema` | Validates Claude/pi agent frontmatter parsing, required fields, name/filename matches, runtime-only field drift, pi bridge wording in Claude bodies, and dialect-specific tool casing. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| Agent check regression | `bash tests/agent-check.sh` | Verifies `agents/check.sh` parity, canonical-pointer, prompt-drift, dependency failures, and the no-mutation `install.sh --check` path under temporary homes. |
| Parent subagent placement | `bash tests/parent-subagent-placement.sh` | Verifies runtime-specific subagent list calls stay in parent-orchestrator guidance and out of child builder prompts. |
| GitLab workflow snippet split | `bash tests/gitlab-local-split-snippets.sh` | Verifies SHA-bound approval, merge, and auto-merge snippets stay separate; retired combined approve+merge snippets stay absent. |
| Install external dependency warnings | `bash tests/install-external-deps.sh` | Verifies missing/present external skill warning behavior under a temporary `HOME`. |
| Install symlink ownership | `bash tests/install-symlink-ownership.sh` | Regression coverage that `install.sh` preserves out-of-repo symlinks (skips them with a `skip:` line) and replaces stale in-repo symlinks under a temporary `HOME`. |
| Review authority explicitness | `bash tests/review-authority-explicit.sh` | Verifies reviewer docs/templates/prompts do not default missing merge authority to approval-only, while preserving explicit `approval-only` as valid authority. |
| Review reject non-mutating path | `bash tests/review-reject-non-mutating.sh` | Verifies reject guidance reports, stops/escalates, and never instructs MR closure without explicit human/project authority. |
| Review Report summary-first contract | `bash tests/review-report-summary-first.sh` | Verifies the Review Report starts with Decision Summary and keeps decision, SHA, CI, findings, checks, and report-link fields visible. |
| Reviewer Lift schema drift | `bash tests/reviewer-lift-schema.sh` | Verifies Reviewer Lift generated copies match the canonical schema and flags unmarked stale duplicate field-list tables. |
| Machine handoff template schema | `bash tests/agent-handoff-templates.sh` | Verifies builder/reviewer machine-readable final handoff templates exist, keep top-level field order, parse as YAML, and use synthetic example URLs. |
| Setup Skill invocation mode | `bash tests/setup-dev-skills-invocation.sh` | Verifies `setup-dev-skills` stays manual-invocation only and docs preserve the ask-before-running guidance. |
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
| `tests/agent-handoff-templates.sh` | Builder/reviewer machine-readable final handoff template field order, YAML parsing, and synthetic example URL safety. |
| `tests/agents-schema.sh` | Claude/pi agent frontmatter parsing, required fields, name/filename matching, runtime-only field drift, and dialect-specific tool casing. |
| `tests/gitlab-local-help-cache.sh` | `/gitlab-local` help-first run-dir cache guidance, context invalidation, and verification-status wording. |
| `tests/gitlab-local-split-snippets.sh` | GitLab workflow snippets remain split into SHA-bound approval, merge, auto-merge, CI watch, and finish helper guidance. |
| `tests/gitlab-workflow-helpers.sh` | `gitlab-local/scripts/gitlab-ci-watch.sh` and `gitlab-local/scripts/gitlab-finish-mr.sh` SHA/CI/authority guard behavior with fake GitLab/Git helpers. |
| `tests/install-external-deps.sh` | `install.sh` warnings for missing required/optional external skills and silence when dependencies exist under a temporary `HOME`. |
| `tests/install-symlink-ownership.sh` | `install.sh` preserves out-of-repo symlinks and replaces stale in-repo symlinks under a temporary `HOME`. |
| `tests/md-links.sh` | Markdown local-link checker diagnostics for broken files, anchors, image targets, and external URL host allowlist behavior. |
| `tests/parent-subagent-placement.sh` | Parent-only subagent discovery guidance stays in the parent-orchestrator recipe and out of child builder prompts. |
| `tests/review-authority-explicit.sh` | Reviewer workflow docs require explicit Merge authority and preserve explicit `approval-only` handling. |
| `tests/review-reject-non-mutating.sh` | Reviewer reject path reports, stops/escalates, and avoids unauthorized MR closure guidance. |
| `tests/review-report-summary-first.sh` | Review Report summary-first contract keeps decision, reviewed SHA, CI status/SHA, findings, local checks, and report-link fields visible. |
| `tests/reviewer-lift-schema.sh` | Reviewer Lift generated-copy blocks match the canonical schema and stale duplicate field-list tables are rejected. |
| `tests/setup-dev-skills-invocation.sh` | `setup-dev-skills` remains manual-invocation only and docs preserve ask-before-running guidance. |

## Workflow regression coverage map

Issue #79 workflow guardrails are runnable through `npm run check` because
`scripts/check.sh` executes every `tests/*.sh` script. The focused commands are:

| Guardrail | Targeted command |
| --- | --- |
| Combined executable approve+merge snippets stay split and absent. | `bash tests/gitlab-local-split-snippets.sh` |
| Missing merge authority blocks approval actions; explicit `approval-only` remains valid. | `bash tests/review-authority-explicit.sh` |
| Reject path reports, stops/escalates, and avoids unauthorized MR closure. | `bash tests/review-reject-non-mutating.sh` |
| Review Report keeps summary-first decision, SHA, CI, findings, checks, and report-link fields. | `bash tests/review-report-summary-first.sh` |
| Builder/reviewer final handoff schemas keep parseable field order and safe example URLs. | `bash tests/agent-handoff-templates.sh` |

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

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
