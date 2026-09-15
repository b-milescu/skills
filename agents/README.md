# Agent dialects

Agent definitions stay split by runtime dialect because a shared file silently
loses working tools when one runtime reads the other's frontmatter schema.

## Which file to edit

- `claude/*.md` — Claude Code sub-agent frontmatter, PascalCase tool names, and
  Claude-only fields such as `effort:`.
- `omp/*.md` — OMP task-agent frontmatter for `~/.omp/agent/agents` and project
  `.omp/agents` discovery: lowercase builtin tool names and canonical
  kebab-case multiword keys.

Both dialect files of one agent share the same `name:` and core procedure. Keep
bodies to launch-critical role boundaries, checklists, reporting contracts, and
runtime-specific wording; point procedure at the
[Doc ownership map](../CLAUDE.md#doc-ownership-map) and routing at
[`start-build`'s route policy](../start-build/reference/parent-orchestrator.md#default-builder-routing).
There is deliberately no generator or shared-fragment system; revisit that in a
dedicated issue or ADR, not a routine agent edit.

## Validate instead of memorising

`npm run check:agents-schema` is the authority for each dialect's allowed tool
names, approved server-scoped MCP selectors, and retired-tool replacements, and
it names the offending file, field, and value. MCP selections stay
least-privilege and server-scoped; only the `gitlab` skill carries GitLab
transport, guard, approval, merge, and finish authority.

After adding or changing an agent, run the
[targeted agent checks](../docs/agents/check-gate.md#targeted-checks), then
`./install.sh` — a missing runtime or variant prints a `skip:` line.
