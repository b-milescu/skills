# agents/skills

Repository of agent skills for the canonical GitLab project `gitlab.example.com/agents/skills`. Each top-level directory is a self-contained skill installed by `install.sh` into agent runtime skill directories.

## Agent skills

This rulebook is a pointer-first entry point. Keep live tracker, label, check-gate, coding guardrails, and workflow details in their owner docs under `docs/agents/`; do not copy those inventories here.

### Routing

- Issue tracker: see `docs/agents/issue-tracker.md`.
- Triage labels: see `docs/agents/triage-labels.md`.
- Domain docs: see `docs/agents/domain.md`.
- Check gate: see `docs/agents/check-gate.md`.
- Coding guardrails: see `docs/agents/coding-guardrails.md`.
- Dev workflows: see `docs/agents/dev-workflows.md`.

### Doc ownership map

| File / path | Owns | Does not own |
| --- | --- | --- |
| `README.md` | Overview, layout, install, skill catalogue. | Live ops or workflow syntax. |
| `CLAUDE.md` | Agent routing and this ownership map. | Repeated inventories or procedures. |
| `docs/agents/` | Repo tracker, labels, gates, guardrails, workflows. | Skill internals or broad onboarding. |
| `setup-dev-skills/` | Creates/reconciles target-repo Agent Setup Docs. | Live policy after setup. |
| `CONTEXT.md` | Project glossary and relationships. | Ops or durable decisions. |
| `docs/adr/` | Durable design decisions. | Glossary or live ops. |
| `gitlab/` | MCP-first transport, fallback syntax, guards, snippets. | Merge/CI/authority policy. |
| `start-build/` | Build, merge/CI/authority, TDD, safety policy. | GitLab syntax or review verdicts. |
| `start-review/` | Review verdict, CI/OQ, authority policy. | GitLab syntax or build policy. |
| `retro/` | Retrospective signals, taxonomy, dispositions, refuter pass. | Issue filing, forge, safety floors. |
