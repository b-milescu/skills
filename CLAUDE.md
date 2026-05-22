# agents/skills

Repository of agent skills for the AI-trading GitLab group. Each top-level directory is a self-contained skill installed by `install.sh` into `~/.claude/skills/`.

## Agent skills

### Issue tracker

Issues live in this repo's GitLab Issues at `gitlab.example.com/agents/skills`, accessed via the `glab` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Check gate

No full local gate is defined; use targeted docs/shell checks for this skills repo. See `docs/agents/check-gate.md`.

### Dev workflows

Use `/gitlab-local`, `/gitlab-to-issues`, `/start-build`, and `/start-review` for GitLab-backed planning, build, and review workflows. See `docs/agents/dev-workflows.md`.
