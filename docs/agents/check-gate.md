# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

No full local gate is currently defined. This repo contains markdown skills and shell install wiring, but no Makefile, package manifest, language project file, or CI config was discovered.

Use the targeted checks below and state `Local gate: PASS — targeted docs/shell checks` in MR Review Packets when they pass.

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Install external dependency warnings | `bash tests/install-external-deps.sh` | Verifies missing/present external skill warning behavior under a temporary `HOME`. |
| Install symlink ownership | `bash tests/install-symlink-ownership.sh` | Regression coverage that `install.sh` preserves out-of-repo symlinks (skips them with a `skip:` line) and replaces stale in-repo symlinks under a temporary `HOME`. |
| Reviewer Lift schema drift | `bash tests/reviewer-lift-schema.sh` | Verifies Reviewer Lift generated copies match the canonical schema and flags unmarked stale duplicate field-list tables. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.pi/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.pi/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near the skill guideline of under 100 lines when practical. |
| Stale naming check | `rg -n "<old-name>|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print | sort` | Confirms expected seed docs exist. |

## Discovery notes

Commands were derived from:

- `README.md` install instructions.
- `install.sh` skill/agent symlink and external dependency warning behavior.
- Skill authoring guideline that `SKILL.md` should stay under 100 lines where practical.
- No `Makefile`, package manifest, language project file, or CI config exists at time of writing.

## CI parity

No CI config was discovered. The targeted checks are the current local evidence source.

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
