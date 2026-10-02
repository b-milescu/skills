# agent-skills

Loose collection of agent skills. Skills are surfaced to each installed agent (Claude Code at `~/.claude/skills/`, OMP at `~/.omp/agent/skills/`) via symlinks.

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

Use Node.js 22.x before installing dependencies; `.nvmrc`, `package.json` `engines.node`, and GitLab CI all declare the Node 22 major line. The repo-local [Check Gate](docs/agents/check-gate.md) owns local validation commands, targeted subsets, CI parity, and MR evidence wording. Follow that doc before asking for review; README intentionally stays pointer-first so gate commands do not drift.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh --check
~/.agent-skills/install.sh
```

GitLab project namespace is `agents/skills`; the npm package name `@agents/skills` is intentionally unchanged.

`install.sh` is idempotent and discovers top-level directories containing `SKILL.md`. Shared `docs/` and `templates/` are not installed as sibling skills. Skill-local resource aliases keep the underlying source's ownership; project-native content remains exposed but never supplies a foreign target's profile/identity/vocabulary/policy. Resolve helper URIs to installed filesystem paths before execution from target CWD. Installer-owned retired links are pruned while foreign/unknown files and links are retained. See [project native integration](docs/agents/native-integration.md) for this repository's actual tools and operation recipes.

Installer reruns also remove stale installer-owned skill and agent symlinks from their runtime roots. In an existing `~/.omp/agent/extensions/` directory, they remove only dangling installer-owned symlinks, resolving both absolute and relative targets with the same repository ownership rules. Working extensions, external symlinks (even dangling ones), and regular files are preserved. Extension cleanup creates no missing directory and never scans HOME recursively.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).
