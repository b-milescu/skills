# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

`npm run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which runs:

- `bash -n install.sh`
- `bash agents/check.sh`
- `npm run check:md`
- `npm run check:links`
- each `tests/*.sh` regression script

Use `Local gate: PASS — npm run check` in MR Review Packets when it passes.

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | Read-only check for Claude/pi agent variant parity (including pi-only drift), Reviewer Lift / Review Report prompt drift, and missing required external skills such as `tdd` in installed agent runtimes. Set `AGENT_SKILLS_CHECK_HOME=<temp-home>` to inspect a disposable HOME. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| Agent check regression | `bash tests/agent-check.sh` | Verifies `agents/check.sh` drift/dependency failures and the no-mutation `install.sh --check` path under temporary homes. |
| Install external dependency warnings | `bash tests/install-external-deps.sh` | Verifies missing/present external skill warning behavior under a temporary `HOME`. |
| Install symlink ownership | `bash tests/install-symlink-ownership.sh` | Regression coverage that `install.sh` preserves out-of-repo symlinks (skips them with a `skip:` line) and replaces stale in-repo symlinks under a temporary `HOME`. |
| Reviewer Lift schema drift | `bash tests/reviewer-lift-schema.sh` | Verifies Reviewer Lift generated copies match the canonical schema and flags unmarked stale duplicate field-list tables. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.pi/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.pi/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near the skill guideline of under 100 lines when practical. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Discovery notes

Commands were derived from:

- `README.md` install instructions.
- `install.sh` skill/agent symlink, read-only `--check`, and external dependency warning behavior.
- `agents/check.sh` source parity, prompt drift, and installed external skill dependency checks.
- `scripts/check.sh` canonical wrapper wiring those checks, Markdown checks, and regression scripts behind one stable command.
- Skill authoring guideline that `SKILL.md` should stay under 100 lines where practical.
- No `Makefile` exists at time of writing.

## CI parity

`.gitlab-ci.yml` runs `npm ci` and `npm run check` in a minimal Node 22 job so GitLab CI installs pinned Markdown tooling from `package-lock.json` before running the same gate used locally.

Full npm cache behavior, install optimization, broader job structure, and MR/default/tag pipeline parity remain separate #54 scope.

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
