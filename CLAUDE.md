# b-milescu/skills

Repository of agent skills for the canonical GitHub project `github.com/b-milescu/skills`. Native Claude and OMP marketplaces distribute the reusable skills and runtime-specific agents.

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
| `docs/agents/` | Tracker, labels, gates, coding guardrails, and dev workflow skill references. | Skill internals or onboarding. |
| `setup-dev-skills/` | Creates/reconciles target-repo Agent Setup Docs. | Live policy after setup. |
| `CONTEXT.md` | Project glossary and relationships. | Ops or durable decisions. |
| `docs/adr/` | Durable design decisions. | Glossary or live ops. |
| `forge/` | Common integration binding, mutation and evidence contracts. | Target-native tools or project policy. |
| `docs/agents/native-integration.md` | This project's native scopes, tools and usable operation recipes. | Foreign target defaults or shared workflow judgment. |
| `start-build/` | Build, merge/CI/authority, TDD, safety policy. | Native transport syntax or review verdicts. |
| `start-review/` | Review verdict, CI/OQ, authority policy. | Native transport syntax or build policy. |
| `retro/` | Retrospective signals, taxonomy, dispositions, refuter pass. | Issue filing, forge, safety floors. |
| `reference/` | Shared runtime-neutral workflow contracts: the Decoupling Contract and the agent-readiness scorecard. | Project policy or per-runtime mechanics. |
| `agents/README.md` | Per-runtime specifics: route ids, model/effort selection, skill invocation and resource paths, dialect rules. | Skill procedures or project policy. |
