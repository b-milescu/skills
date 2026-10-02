# agent-skills

Loose collection of agent skills. The developer install surfaces skills via symlinks to Claude Code (`~/.claude/skills/`) and OMP (`~/.omp/agent/skills/`). The portable npm core payload contains materialized snapshots instead.

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

The approved replacement distribution/lifecycle contract and bounded runtime
compatibility evidence live in [the public installer contract](docs/installer-contract.md).
That contract is not a released executable; the current installation below remains
in force until the separately reviewed clean cutover.

```bash
git clone git@gitlab.example.com:agents/skills.git ~/.agent-skills
~/.agent-skills/install.sh --check
~/.agent-skills/install.sh
```

GitLab project namespace is `agents/skills`; the npm package name `@agents/skills` is intentionally unchanged.

`install.sh` is idempotent and discovers top-level directories containing `SKILL.md`. Shared `docs/` and `templates/` are not installed as sibling skills. Skill-local resource aliases keep the underlying source's ownership; project-native content remains exposed but never supplies a foreign target's profile/identity/vocabulary/policy. Resolve helper URIs to installed filesystem paths before execution from target CWD. Installer-owned retired links are pruned while foreign/unknown files and links are retained. See [project native integration](docs/agents/native-integration.md) for this repository's actual tools and operation recipes.

Installer reruns also remove stale installer-owned skill and agent symlinks from their runtime roots. In an existing `~/.omp/agent/extensions/` directory, they remove only dangling installer-owned symlinks, resolving both absolute and relative targets with the same repository ownership rules. Working extensions, external symlinks (even dangling ones), and regular files are preserved. Extension cleanup creates no missing directory and never scans HOME recursively.

Requires GNU `realpath` (Linux ships it by default; macOS: `brew install coreutils`).

## Portable core payload (not an executable release)

`npm pack` prepares an explicit `core/` allowlist containing all eight skills,
materialized skill-local docs/templates, sibling cross-skill resources and
`core/agents/{claude,omp}` reusable routes. It excludes complete project-native
`.claude/agents` and `.omp/agents`, development tooling and checkout dependencies.
Git's symlink-disabled resource-alias files are materialized too. Generated
`core/` and tarballs are disposable build output, not new policy owners.

Acquire a reviewed immutable source archive anonymously over verified HTTPS,
then pack and install it in an isolated package root with Node 22/npm:

```sh
snapshot=<reviewed-full-commit-SHA>
curl -q --fail --silent --show-error --proto '=https' --tlsv1.2 \
  --output source.tar.gz \
  "https://gitlab.example.com/agents/skills/-/archive/$snapshot/skills-$snapshot.tar.gz"
mkdir source
tar -xzf source.tar.gz --strip-components=1 -C source
npm pack ./source --pack-destination .
npm install --prefix ./installed --omit=dev --ignore-scripts ./ai-trading-skills-0.0.0.tgz
```

This archive recipe requires curl, tar, Node 22 and npm, not Git/SSH or private
registry credentials. DNS/reachability and trusted TLS for the approved origin
are prerequisites. npm installs the helper's `js-yaml` runtime dependency with
the package; no developer checkout or devDependencies are needed. Keep the whole
installed package and its dependency tree: copying a helper or projecting skills
without their package-owned dependencies is not a portable install.

Resolve `skill://` entries/resources against
`installed/node_modules/@agents/skills/core/<skill>` and execute the resolved
helper paths from the target CWD. Shared docs/templates are resources, not sibling
skills. Included repository-native policy remains source-owned evidence, never
a foreign target's profile/configuration. User-only invocation restrictions,
independent review and safety floors remain authoritative.

The retained `0.0.0` package is private and has no executable; this command is a
source-packaging recipe, not a released `npx` installer or public npm download.
The first complete executable release remains `0.1.0`, through the explicit
project-16 registry in the [approved contract](docs/installer-contract.md).
Downstream delivery owns catalog/client projection and publication; no live
installation, MCP registration or installer cutover happens here.
