# agent-skills

Loose collection of agent skills. Skills are surfaced to each installed agent (Claude Code at `~/.claude/skills/`, pi at `~/.pi/agent/skills/`) via symlinks.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`).
- `local-gitlab/` — direct `glab` command reference for local/self-hosted GitLab work.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh
```

`install.sh` is idempotent — re-run it after adding new skills. It auto-discovers every top-level skill dir, installs skills into each agent dir that exists on this host (skipping the rest with a clear `skip:` line), and refuses to overwrite a non-symlink target. For GitLab work, load `local-gitlab` and use direct `glab` commands from inside the target repo.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).
