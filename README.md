# agent-skills

Loose collection of agent skills. Skills are surfaced to each installed agent (Claude Code at `~/.claude/skills/`, pi at `~/.pi/agent/skills/`) via symlinks.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`).
- `templates/` — shared template files (ADR, filling guides). Shared via symlinks (e.g. `adr.md`) or relative-path cross-references from skill-specific docs.

## Skills

| Skill | Purpose |
|---|---|
| `local-gitlab` | `glab` CLI command reference for local/self-hosted GitLab work. |
| `start-build` | Pick up GitLab issues, implement with TDD, open Draft MRs with Review Packets. |
| `start-review` | Review GitLab MRs against project rules, post Review Reports, approve/merge. |
| `to-issues` | Break approved plans/specs into GitLab issues using local tracker docs and triage labels. |

## External dependencies

- **`tdd`** — from `~/.agents/skills/tdd`. Both `start-build` and `start-review` load this skill for TDD principles. Install it from the companion skills repo before using build/review workflows.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh
```

`install.sh` is idempotent — re-run it after adding new skills. It auto-discovers every top-level skill dir (containing `SKILL.md`), installs skills into each agent dir that exists on this host (skipping the rest with a clear `skip:` line), and refuses to overwrite a non-symlink target. For GitLab work, load `local-gitlab` and use direct `glab` commands from inside the target repo.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).
