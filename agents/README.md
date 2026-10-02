# Agent dialects

Agent definitions stay split by runtime: Claude Code and OMP have different
frontmatter, tool spellings and discovery rules. No shared-fragment generator
or metadata overlay is involved.

## Reusable presets and complete project declarations

`claude/*.md` and root `mr-*.md` are reusable presets distributed by their native
marketplaces. They pin roles/models/effort and canonical workflow
skills without selecting native servers. The invoked target's confirmed
integration determines its native tools and action-scoped authority.

This repository's complete same-name declarations live in
[`.claude/agents/`](../.claude/agents/) and [`.omp/agents/`](../.omp/agents/).
They select this project's confirmed servers and point to canonical
`start-build`/`start-review` and `forge`, plus
[the project integration](../docs/agents/native-integration.md). These are whole
runtime definitions, not overlays on installed presets or copies of skill
procedures. Native marketplace metadata excludes these project declarations. For another target,
manual confirmed setup writes that target's complete declarations from its
own configuration/evidence; strings alone do not establish scoped identity.

Builder and mandatory independent final-reviewer roles remain distinct.
Claude pins `claude-opus-4-8` with medium/xhigh effort; OMP pins `pi/task` with
medium/xhigh thinking. Canonical workflows own task-selected specialists;
neither route unconditionally preloads TDD. See
[the default-builder policy](../start-build/reference/parent-orchestrator.md#default-builder-routing).

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
path, pins and canonical skill-entry source/bytes, not just a route name.

## Validate and observe separately

`npm run check:agents-schema` validates both reusable and native project
frontmatter. Explicit paths work through either checker:

```sh
node scripts/check-agent-schemas.mjs /target/.claude/agents /target/.omp/agents
bash agents/check.sh /target/.claude/agents /target/.omp/agents
```

Every requested directory must collect agents; an empty request fails even
alongside a valid request. The schema checks runtime syntax and exact or
server-scoped MCP selectors without a server catalogue. Syntax acceptance is
not confirmation that a tool exists, is authenticated, or is accessible.

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
obedience, Claude execution or hard MCP confinement. OMP's child executor
proxies parent MCP tools: frontmatter records selection intent, not an
isolation boundary. Verify actually available tools and scoped read-only
native identity from the real spawning session separately. Do not widen to a
generic `mcp_*` selector or patch an external runtime to manufacture proof.

Native installation and lifecycle commands live in [README](../README.md#install-on-a-new-machine);
[Check Gate](../docs/agents/check-gate.md#native-install-smoke-requirement)
owns the required isolated proof. Native managers own removal; existing user
links and other unmanaged content are not automatically migrated or deleted.

Claude exposes reusable agents as `skills:mr-builder` and
`skills:mr-reviewer-final`; use qualified IDs for deterministic plugin routing.
OMP exposes bare `mr-builder` and `mr-reviewer-final`, with project-native
same-name declarations taking precedence. Its root `agents/*.md` files select
only OMP dialect files; Claude metadata explicitly selects its two dialect files.

Canonical logical skill IDs stay stable. OMP natively resolves `skill://`;
Claude entry and agent bodies map logical resources through
`${CLAUDE_PLUGIN_ROOT}`. See the bootstrap in each installed skill entry before
reading or executing resources from a foreign CWD. Shared docs retain their
source ownership and never become another target's configuration.
