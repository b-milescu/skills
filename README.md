# agent-skills

Loose collection of agent skills, with shared shell-script tooling under `scripts/`. Skills are surfaced to each installed agent (Claude Code at `~/.claude/skills/`, pi at `~/.pi/agent/skills/`) via symlinks; shared scripts are surfaced via symlinks into `~/.local/bin/`.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`).
- `scripts/<group>/` — thin shell-script wrappers shared across skills.
  - `scripts/gitlab/gl-*` — composite `glab` operations used by `start-build` and `start-review`. Run any wrapper with `--help` for usage.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh
```

`install.sh` is idempotent — re-run it after adding new skills or scripts. It auto-discovers every top-level skill dir and every executable under `scripts/<group>/`, installs skills into each agent dir that exists on this host (skipping the rest with a clear `skip:` line), refuses to overwrite a non-symlink target, and warns if `~/.local/bin/` isn't on `PATH`. Verify the result with `gl-preflight` from inside any GitLab-backed repo.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).

## Adding shared scripts

1. Drop the script under `scripts/<group>/`, make it executable, give it a `--help` block.
2. Run `./install.sh` to surface it under `~/.local/bin/`.
3. Reference it from skill docs only for *composite* operations — single-shot CLI calls stay direct.
