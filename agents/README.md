# Agent dialects

Agent definitions stay split by runtime: Claude Code and OMP have different
frontmatter, tool spellings and discovery rules. No shared-fragment generator
or metadata overlay is involved. This file is the single home for per-runtime
specifics (route ids, model/effort selection, skill invocation and resource
paths); the skills themselves stay runtime-neutral.

## Reusable presets and complete project declarations

`claude/*.md` and `omp/*.md` are canonical reusable presets. Native OMP's
root `change-*.md` entrypoints are symlinks into `omp/`. Native marketplaces
preserve roles and canonical workflow skills.

No route declares `tools`: every preset and every project declaration inherits all
of the parent session's tools, MCP tools included (each runtime still withholds the
few tools it never gives a subagent). The invoked target's confirmed integration
therefore decides which native tools a route reaches, and action-scoped authority
comes from the canonical workflows, not from frontmatter.

This repository's complete same-name declarations live in
[`.claude/agents/`](../.claude/agents/) and [`.omp/agents/`](../.omp/agents/).
They point to canonical `start-build`/`start-review` and `forge`, plus the target
project's integration doc, and reach GitHub through the parent session's github
MCP server or `gh`. These are whole runtime definitions, not overlays on installed
presets or copies of skill procedures. Native marketplace metadata excludes these
project declarations. For another target, manual confirmed setup writes that
target's complete declarations from its own configuration/evidence; strings alone
do not establish scoped identity.

Builder and mandatory independent final-reviewer roles remain distinct.
Canonical workflows own task-selected specialists.

## Route ids

The two routes are `change-builder` (child builder) and `change-reviewer-final`
(mandatory independent final reviewer).

| Runtime | Reusable route ids | Reusable source |
| --- | --- | --- |
| Claude Code | `skills:change-builder`, `skills:change-reviewer-final` | `agents/claude/<route>.md`, selected explicitly by `.claude-plugin/plugin.json` |
| OMP | `change-builder`, `change-reviewer-final` | `agents/<route>.md` (symlinks into `agents/omp/`); root `agents/*.md` select only OMP dialect files |

Claude prefixes plugin agents with the plugin namespace, so use the qualified ids
for deterministic plugin routing. OMP exposes bare ids. In either runtime an
effective same-name project declaration may expose a bare id and take native
precedence. Resolve each route from the spawning session's effective agent
inventory with verified runtime/source provenance, not from a guessed source
filename or a basename-only comparison, and verify the selection independently
in each runtime from the intended checkout. A namespace qualifies the same
canonical route; it is not an alias or a substitute. Preserve the basename, the
canonical skills and reviewer independence.

If a required route is unavailable or its effective source is ambiguous, stop
with a route-unavailable blocker and an explicit parent/operator decision. Never
select a generic specialist, shim, old filename, cross-runtime route or downgrade.

## Model and effort selection

Selection is runtime-owned. Shipped declarations pin no model or effort, prompt
prose is not model/effort enforcement, and selection never relaxes canonical
route, independent-review, exact-candidate gate or authority boundaries.

- **Claude Code:** declarations use `model: inherit` and omit `effort`. The parent
  may select a supported model through the native Agent invocation's model
  override; without it, the model inherits the parent conversation. Omitted effort
  inherits the session, subject to native model support and limits. There is no
  per-invocation Agent effort parameter and no `effort: inherit` declaration.
- **OMP:** declarations omit `model` and `thinking-level`; native parent/runtime
  task selection and defaults resolve them. Use only overrides exposed by the
  actual callable runtime interface, not internal executor arguments. Installed
  OMP exposes per-task `effort` (`lo`/`med`/`hi`) only behind `task.enableEffort`;
  this repository neither enables that setting nor adds a model parameter to
  `task`. Operator overrides and supported levels remain runtime-owned.

Installation or selected-source metadata is not live execution proof: after a
frontmatter or routing change, take a fresh spawning-session operator observation
of the effective model/effort, and report unavailable or unauthorized execution.

## Durable child output

Parent-readable handoffs must survive isolated-worktree cleanup. In OMP, do not
rely on `task` with `worktree: true`, a relative `output` path and
`outputMode: "file-only"` for any artifact the parent must read later: that
combination can return a path inside a temporary `omp-worktree-*` checkout,
which the parent cannot read once the worktree is removed. Prefer inline child
output. When a file output is required, pass an absolute path under a durable
run directory created outside any `omp-worktree-*` path, and make sure the
directory exists before launch. Recover a stale temporary-worktree path from
durable run artifacts instead of treating the missing local file as the
delivery record.

## Skill invocation and resource paths

Skills link their own resources, the shared reference docs and the shared
templates by relative paths. A relative path resolves against the directory of the
file that contains it, as in standard Markdown, never against the skill directory,
so skill entries carry no per-runtime bootstrap. Run helper scripts by their
resolved absolute path inside the installed skill the runtime loaded, including from
a foreign CWD and never from a copy in the checkout under review (a change must not
be validated by its own modified validator), and strip Markdown
`#fragments` before filesystem reads or Bun execution. Plugin skills live under
`${CLAUDE_PLUGIN_ROOT}/<skill>/` in Claude Code and resolve as `skill://<skill>/`
in OMP.

| Dialect | Skill ids | Declared on the agent by | Activated at runtime by |
| --- | --- | --- | --- |
| Claude Code (`agents/claude/*.md`, `.claude/agents/*.md`) | `skills:<name>`; user commands use the same namespace | `skills:` frontmatter preloads bodies by namespaced id (`skills:start-build`, `skills:forge`); it is not an invocation allowlist | Invoke additional eligible installed skills via the `Skill` tool at their entry, as `skills:<name>` |
| OMP (`agents/*.md` excluding this README, `.omp/agents/*.md`) | bare `<name>`; `/skill:<name>` as the user command; `skill://<name>[/resource]` for resources | `autoload-skills:` frontmatter preloads bodies at session start, separately from the inherited discovery inventory | The OMP skill-load mechanism enters preloads; eligible unpreloaded entries remain available through runtime entry resolution (`skill://<name>`) |

Both dialects enter a skill at its `SKILL.md` start, not mid-policy. Preload,
discovery eligibility, skill invocation and reference reads are distinct: an
available or resolvable entry is not invocation permission, so check the
authoritative frontmatter for user-only restrictions before on-demand invocation.
Reserve "load" for reference reads and other file/context loads, never for skill
activation. Shared reference docs retain their source ownership and never become
another target's configuration.

## Runtime-specific precedence

- **OMP:** the installed `src/task/discovery.ts` selects the nearest project
  `.omp/agents` before user `~/.omp/agent/agents`, then extension-package agents,
  installed plugins/Claude marketplace agents and bundled agents. It does not
  load `.claude/agents` as an OMP-native agent root. The actual loader harness
  below verifies the selected project file against a same-name native marketplace
  preset in fresh processes.
- **Claude Code:** [its scope documentation](https://code.claude.com/docs/en/subagents.md#choose-the-subagent-scope)
  independently specifies managed definitions, CLI `--agents`, nearest project
  `.claude/agents`, user `~/.claude/agents`, then plugins, in descending priority.
  Higher-priority managed/CLI definitions can override a project declaration.
  This repository's harness does not prove live Claude selection or execution.

Launch the spawning session from the intended checkout after declarations are
present. A child execution-CWD change is not discovery or proof that a cached
same-name route was reselected. Repeat fresh discovery independently from
allocated and revision checkouts. Record selected `source`, `filePath`, real
path, declared metadata and canonical skill-entry source/bytes, not just a route name.

## Validate and observe separately

`bun run check:agents-schema` validates both reusable and native project
frontmatter. Explicit paths work through either checker:

```sh
bun scripts/check-agent-schemas.mjs /target/.claude/agents /target/.omp/agents
bash agents/check.sh /target/.claude/agents /target/.omp/agents
```

Every requested directory must collect agents; an empty request fails even
alongside a valid request. The schema checks runtime syntax. `tools` is optional
(these routes omit it); when a target declares it, each builtin tool name is
validated against the pinned tool table for its runtime (the Claude Code table; the
OMP table mirrors the 17.3.7 builtins), so a real tool missing from a table fails,
while MCP selectors get a syntax check only. Neither confirms that a tool is
available in the spawning session, authenticated, or accessible.

Run the actual disposable-HOME loader scenario (requires the installed OMP
source and Bun):

```sh
OMP_REQUIRE_LOADER=1 \
OMP_SPAWN_CWD=/spawning/checkout \
OMP_ALLOCATED_CWD=/allocated/checkout \
OMP_REVISION_CWD=/revision/checkout \
bash tests/omp-agent-loader-smoke.sh
```

Without explicit allocated/revision paths it uses isolated filesystem copies
of native declarations, and labels that narrower proof. The harness uses a
fresh process for each discovery, and separately checks available canonical
entries through actual skill discovery and `skill://` access, including an
unpreloaded entry and absent-inventory rejection. Entries resolve to the
native manager's disposable installed cache; project agent provenance and
canonical installed-entry provenance are separate facts.

No harness claim covers live model routing, native mutation, reviewer
obedience or Claude execution. Routes inherit every tool of the parent session,
so verify the tools actually available and the scoped read-only native identity
from the real spawning session separately, and never patch an external runtime to
manufacture proof.

Native installation and lifecycle commands live in [README](../README.md#install-on-a-new-machine);
[Check Gate](../docs/agents/check-gate.md#native-install-smoke-requirement)
owns the required isolated proof. Native managers own removal; existing user
links and other unmanaged content are not automatically migrated or deleted.
