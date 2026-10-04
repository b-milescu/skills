# agent-skills

Eight reusable agent skills and runtime-specific builder/final-reviewer presets, distributed through native Claude Code and OMP marketplaces.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`), with skill-local `shared-templates/` symlinks (plus `shared-reference/` for `start-build`, `issue-delivery-loop` and `plan-to-issues`) for shared resource reads.
- `agents/` — runtime-specific agent definitions; see `agents/README.md` for Claude Code vs OMP dialect rules, route ids, model/effort selection and skill invocation.
- `scripts/` — repo-local Check Gate and maintenance scripts; see `scripts/README.md`.
- `templates/` — shared template files (ADR, filling guides). Referenced through `shared-templates/` skill-local symlinks, not installed as runtime skill-root entries.
- `reference/` — shared reference docs (Decoupling Contract, agent-readiness scorecard). Referenced through `shared-reference/` skill-local symlinks, not installed as runtime skill-root entries.

## Skills

| Skill | Purpose |
|---|---|
| `setup-dev-skills` | Manual Setup Skill (`disable-model-invocation: true`) that scaffolds per-repo Agent Setup Docs. Invoke explicitly as `/setup-dev-skills`; agents must ask before running or writing. |
| `forge` | Five-operation instruction seam using the invoked target's confirmed integration. |
| `start-build` | Implement one issue test-first as a Draft change request with a Review Packet. |
| `start-review` | Independently review one change request at an exact commit. |
| `issue-delivery-loop` | Coordinate bounded issue batches under the Decoupling Contract. |
| `plan-to-issues` | Publish an approved plan as tracker issues. Slash is `/plan-to-issues`. |
| `cleanup-codebase` | Plan subtractive repo maintenance (deslop, destale); planning only. |
| `retro` | Mine a finished delivery session for friction; proposes follow-up issues only. |

## Task-selected specialists

Dev Workflows invoke applicable installed specialists on demand under the shared
[selection policy](start-build/reference/context-and-planning.md#task-selected-specialists).
Runtime workflow/forge preloads are distinct from entry access and invocation
eligibility; see [skill invocation](agents/README.md#skill-invocation-and-resource-paths).

## Check before install or review

Use Node.js 22.x before installing dependencies; `.nvmrc`, `package.json` `engines.node`, and GitHub Actions (via `.nvmrc`) all declare the Node 22 major line. The repo-local [Check Gate](docs/agents/check-gate.md) owns local validation commands, targeted subsets, CI parity, and PR evidence wording. Follow that doc before asking for review; README intentionally stays pointer-first so gate commands do not drift.

## Install on a new machine

The public Git source is <https://github.com/b-milescu/skills> (shorthand
`b-milescu/skills`). Native clients own installation, updates and removal. No
npm executable or custom installer is published, and no MCP
catalogue/configuration is automatically installed. Keep each native
installation's complete resource tree; copying standalone helpers is not
supported.

### Prerequisites

- Claude Code or OMP with plugin-marketplace support.
- Git, and Node.js 22.x on `PATH`. The bundled helpers need no npm packages.
- For change-request workflows, a tool your runtime can use to reach your code host and issue tracker (an MCP server or a CLI). Nothing is bundled; the `setup-dev-skills` skill records the choice per project.
- Optional: a memory plugin or MCP server for `retro` lookback.

Contributors to this repository also need npm and bash for the [Check Gate](docs/agents/check-gate.md), `gh` plus the GitHub MCP server for its own workflow (see [native integration](docs/agents/native-integration.md)), and optionally Bun plus an OMP source checkout for the loader smoke test.

### Claude Code

```sh
claude plugin marketplace add b-milescu/skills
claude plugin install skills@skills --scope user
claude plugin marketplace update skills
claude plugin update skills@skills --scope user
claude plugin uninstall skills@skills --scope user
```

The plugin exposes all eight skills and only the two reusable Claude agent
files. Agent identifiers are `skills:change-builder` and
`skills:change-reviewer-final`; prefer qualified plugin IDs when selecting
reusable routes. Skill commands use the `skills:<logical-name>` namespace.
Local `--plugin-dir` development loading is not equivalent installation proof.

### OMP

```sh
omp plugin marketplace add b-milescu/skills
omp plugin install skills@skills --scope user
omp plugin marketplace update skills
omp plugin upgrade skills@skills --scope user
omp plugin uninstall skills@skills --scope user
```

OMP uses the same marketplace and the OMP dialect marker. Its reusable agent
IDs stay bare: `change-builder` and `change-reviewer-final`; skills use
`/skill:<logical-name>` and native `skill://<logical-name>[/resource]`.
OMP Git marketplace installation does not install npm dependencies. Installed
workflow helpers therefore carry their minimal static YAML dependency and
license; they do not require a developer checkout's `node_modules`.

Both native surfaces expose shared reference docs and templates as resources,
not additional skills, and exclude complete project-native agent declarations
from reusable defaults. The routes declare no `tools` and inherit all of the
parent session's tools. Canonical logical skill IDs remain unchanged. Skills
link their resources by relative paths that resolve against the directory of the
file containing them, as in standard Markdown, so both runtimes resolve them
without a per-runtime bootstrap; helper scripts run by their resolved absolute
path, including from the target CWD. See
[route ids, model/effort selection and skill invocation](agents/README.md#skill-invocation-and-resource-paths).
Source-owned native docs never become a foreign target's profile or policy.

Existing legacy user links, user/site agents, extensions, MCP settings and
credentials are preserved; installation does not automatically migrate or delete
them. Operators own native configuration and any intentional legacy cleanup.
Start a fresh runtime session after installation or route/frontmatter updates.
[Check Gate](docs/agents/check-gate.md#native-install-smoke-requirement) owns
isolated installation/discovery/lifecycle proof; discovery metadata alone does
not prove live model routing or authentication.

## License

Released under the [MIT license](LICENSE).
