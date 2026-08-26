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
| `README.md` | Human-facing repo overview, layout, install instructions, and broad skill catalogue. | Live tracker labels, gate commands, workflow command syntax, or domain decisions. |
| `CLAUDE.md` | Agent entry-point routing plus this ownership map. | Repeated live inventories from `docs/agents/` or detailed workflow procedures. |
| `docs/agents/` | Canonical repo-local operating docs for tracker location, label vocabulary, domain-doc loading, check gates, coding guardrails, and dev workflow skill references. | Skill implementation internals or broad README-style onboarding. |
| `setup-dev-skills/` | Setup Skill that creates or reconciles repo-local Agent Setup Docs in target repos. | This repo's live operating inventory after setup output has been written. |
| `CONTEXT.md` | Project language, glossary, relationships, and rejected synonyms. | Operational tracker/gate/workflow details or durable design decisions. |
| `docs/adr/` | Durable design decisions when present. | Glossary ownership or live operational inventories. |
| `gitlab/` | GitLab transport mechanics: MCP-first snippet contracts, guarded help-first `glab` fallback syntax, flags/JSON shapes, SHA-pinning, local-pitfall/snippet inventory, and safe-text helper behavior. | Merge/CI/authority policy (helper scripts may embed it as implementation, but the prose owner is the workflow skill). |
| `start-build/` | Build behavior and policy, including merge/CI/authority and TDD/safety rules; the agent prompt is a thin pointer. | GitLab transport/fallback syntax (see `gitlab/`) or review-verdict policy (see `start-review/`). |
| `start-review/` | Review behavior and policy, including the canonical CI/Open-Question decision tables and verdict/authority rules; the agent prompt is a thin pointer. | GitLab transport/fallback syntax (see `gitlab/`) or build/TDD policy (see `start-build/`). |
| `retro/` | Retrospective behavior and policy: friction signal catalogue, `RF-N` taxonomy and dispositions, the refuter pass and its verdicts, and owner-doc routing rules. | Issue-filing mechanics (see `plan-to-issues/`), forge transport, or the safety floors themselves (see `docs/effort-scaling.md`). |
