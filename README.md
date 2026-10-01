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
| `gitlab` | MCP-first GitLab transport with guarded help-first `glab` fallback. |
| `forge` | Five-operation provider seam for GitLab, GitHub, and Azure DevOps. |
| `start-build` | Implement one issue test-first as a Draft change request with a Review Packet. |
| `start-review` | Independently review one change request at an exact commit. |
| `issue-delivery-loop` | Coordinate bounded issue batches under the Decoupling Contract. |
| `plan-to-issues` | Publish an approved plan as tracker issues. Slash is `/plan-to-issues`. |
| `cleanup-codebase` | Plan subtractive repo maintenance (deslop, destale); planning only. |
| `retro` | Mine a finished delivery session for friction; proposes follow-up issues only. |

## External skill dependencies

This repo does not vendor every skill referenced by docs or prompts. Install external skills into each runtime skill directory that exists on the host (for example `~/.claude/skills/<name>` and/or `~/.omp/agent/skills/<name>`).

| Skill | Requirement | Referenced by | Fallback |
|---|---|---|---|
| `tdd` | Required for behavior-touching build/review work | `start-build`, `start-review`, `mr-builder`, `mr-reviewer` | Do not run behavior-touching build/review workflows until installed. |

`install.sh` warns for missing declared external skills in each target runtime skill directory; warnings do not vendor or install those external skills. `cleanup-codebase` also refers to `simplify`, `code-review`, and `security-review`, which are harness built-ins rather than installable skill dependencies.

## Check before install or review

Use Node.js 22.x before installing dependencies; `.nvmrc`, `package.json` `engines.node`, and GitLab CI all declare the Node 22 major line. The repo-local [Check Gate](docs/agents/check-gate.md) owns local validation commands, targeted subsets, CI parity, and MR evidence wording. Follow that doc before asking for review; README intentionally stays pointer-first so gate commands do not drift.

## Install on a new machine

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh --check
~/.agent-skills/install.sh
```

GitLab project namespace is `agents/skills`; the npm package name `@agents/skills` is intentionally unchanged.

`install.sh` is idempotent — re-run it after adding new skills. It auto-discovers every top-level skill dir (containing `SKILL.md`) and installs only those directories into each agent skill root; shared repo `docs/` and `templates/` are intentionally not symlinked as skill-root siblings because some runtimes interpret every skill-root directory as a skill. Each installed skill exposes skill-local resource symlinks (`docs/` and `shared-templates/`) for `skill://<skill>/docs/...` and `skill://<skill>/shared-templates/...` reads. The installer warns for missing declared external skill dependencies and refuses to overwrite non-symlink targets or symlinks pointing outside this repo. For GitLab work, invoke `gitlab`, use MCP-first transport, and reserve direct `glab` commands for documented guarded fallback/helper cases from inside the target repo.

Installer reruns also remove stale installer-owned skill and agent symlinks from their runtime roots. In an existing `~/.omp/agent/extensions/` directory, they remove only dangling installer-owned symlinks, resolving both absolute and relative targets with the same repository ownership rules. Working extensions, external symlinks (even dangling ones), and regular files are preserved. Extension cleanup creates no missing directory and never scans HOME recursively.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).
