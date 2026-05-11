# agent-skills

Loose collection of Claude Code agent skills, with shared shell-script tooling under `scripts/`. Skills are surfaced to Claude via symlinks into `~/.claude/skills/`; shared scripts are surfaced via symlinks into `~/.local/bin/`.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`).
- `scripts/<group>/` — thin shell-script wrappers shared across skills.
  - `scripts/gitlab/gl-*` — composite `glab` operations used by `start-build` and `start-review`. Run any wrapper with `--help` for usage.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills

mkdir -p ~/.claude/skills ~/.local/bin

# Skills → ~/.claude/skills/<name>
for d in ~/.agent-skills/*/; do
  name=$(basename "$d")
  [[ "$name" == "scripts" ]] && continue
  ln -sf "../../.agent-skills/$name" ~/.claude/skills/"$name"
done

# Shared scripts → ~/.local/bin/<name>
for f in ~/.agent-skills/scripts/gitlab/gl-*; do
  name=$(basename "$f")
  ln -sf "../../.agent-skills/scripts/gitlab/$name" ~/.local/bin/"$name"
done
```

`~/.local/bin/` must be on `PATH`. Verify with `gl-preflight` from inside any GitLab-backed repo.

## Adding shared scripts

1. Drop the script under `scripts/<group>/`, make it executable, give it a `--help` block.
2. Symlink it into `~/.local/bin/` with a relative target (`../../.agent-skills/scripts/<group>/<name>`).
3. Reference it from skill docs only for *composite* operations — single-shot CLI calls stay direct.
