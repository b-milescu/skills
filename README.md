# agent-skills

Eight reusable agent skills and runtime-specific builder/final-reviewer presets, distributed through native Claude Code and OMP marketplaces.

## Layout

- `<skill-name>/` — one directory per skill (entry point: `SKILL.md`), with skill-local `docs/` and `shared-templates/` symlinks for shared resource reads.
- `agents/` — runtime-specific agent definitions; see `agents/README.md` for Claude Code vs OMP dialect rules.
- `scripts/` — repo-local Check Gate and maintenance scripts; see `scripts/README.md`.
- `templates/` — shared template files (ADR, filling guides). Referenced through `shared-templates/` skill-local symlinks, not installed as runtime skill-root entries.

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
An external `tdd` skill is not required to install or check this repo; observable
TDD/native-test rules still apply. Runtime workflow/forge preloads are distinct
from entry access and invocation eligibility; see
[skill activation](docs/agents/dev-workflows.md#skill-activation-mechanism).
`cleanup-codebase` also refers to `simplify`, `code-review`, and `security-review`,
which are harness built-ins rather than installable skill dependencies.

## Check before install or review

Use Node.js 22.x before installing dependencies; `.nvmrc`, `package.json` `engines.node`, and GitHub Actions (via `.nvmrc`) all declare the Node 22 major line. The repo-local [Check Gate](docs/agents/check-gate.md) owns local validation commands, targeted subsets, CI parity, and PR evidence wording. Follow that doc before asking for review; README intentionally stays pointer-first so gate commands do not drift.

## Install on a new machine

The public Git source is <https://github.com/b-milescu/skills> (shorthand
`b-milescu/skills`). Acquisition requires Git. Native clients own
installation, updates and removal. No npm executable or custom installer is
published, and no MCP catalogue/configuration is automatically installed.
Installed Node helpers require Node.js 22.x. Keep each native installation's
complete resource tree; copying standalone helpers is not supported.

### Claude Code

```sh
claude plugin marketplace add b-milescu/skills
claude plugin install skills@skills --scope user
claude plugin marketplace update skills
claude plugin update skills@skills --scope user
claude plugin uninstall skills@skills --scope user
```

The plugin exposes all eight skills and only the two reusable Claude agent
files. Agent identifiers are `skills:mr-builder` and `skills:mr-reviewer-final`;
prefer qualified plugin IDs when selecting reusable routes. Skill commands use
the `skills:<logical-name>` namespace. Native Git marketplace installation
prepares package dependencies; local `--plugin-dir` development loading does
not, so it is not equivalent installation/dependency proof.

### OMP

```sh
omp plugin marketplace add b-milescu/skills
omp plugin install skills@skills --scope user
omp plugin marketplace update skills
omp plugin upgrade skills@skills --scope user
omp plugin uninstall skills@skills --scope user
```

OMP uses the same marketplace and the OMP dialect marker. Its reusable agent
IDs stay bare: `mr-builder` and `mr-reviewer-final`; skills use
`/skill:<logical-name>` and native `skill://<logical-name>[/resource]`.
OMP Git marketplace installation does not install npm dependencies. Installed
workflow helpers therefore carry their minimal static YAML dependency and
license; they do not require a developer checkout's `node_modules`.

Both native surfaces expose shared docs/templates as resources, not additional
skills, and exclude complete project-native agent declarations from reusable
defaults. Canonical logical skill IDs remain unchanged. Claude does not natively
resolve `skill://`: installed entry/agent bodies bootstrap its filesystem mapping
through `${CLAUDE_PLUGIN_ROOT}`. Follow that entry contract before executing
resolved helper paths from the target CWD; see
[agent dialect/resource guidance](agents/README.md#validate-and-observe-separately).
Source-owned native docs never become a foreign target's profile or policy.

Existing legacy user links, user/site agents, extensions, MCP settings and
credentials are preserved; installation does not automatically migrate or delete
them. Operators own native configuration and any intentional legacy cleanup.
Start a fresh runtime session after installation or route/frontmatter updates.
[Check Gate](docs/agents/check-gate.md#native-install-smoke-requirement) owns
isolated installation/discovery/lifecycle proof; discovery metadata alone does
not prove live model routing, authentication or hard tool confinement.

## License

Released under the [MIT license](LICENSE).
