# Agent dialects

Keep agent definitions split by runtime dialect. change request !31 showed why: a shared
agent file can silently lose working tools when one runtime reads another
runtime's frontmatter schema.

## Layout

- `claude/*.md` — Claude Code dialect.
- `omp/*.md` — OMP task-agent dialect for `~/.omp/agent/agents` and project `.omp/agents` discovery.
- Match agent names across both dirs with the same `name:` and the same core
  procedure.
- See [`start-build`'s parent-orchestrator route policy](../start-build/reference/parent-orchestrator.md#default-builder-routing)
  for the shared builder/reviewer basenames, dialect resolution, model pins, and unavailable-route handling.

## Claude Code variant

Use Claude Code's documented sub-agent frontmatter only. Use PascalCase tool
names from the tools reference, for example `Bash`, `Read`, `Edit`, and `Write`.
Keep Claude-only fields such as `effort:` here.

Remove retired bridge language from Claude bodies: no `contact_supervisor`, no
`intercom`, and no `Supervisor coordination` section. Add explicit
anti-fabrication reporting rules when the agent interacts with GitLab or other
remote state.

## OMP variant

Use OMP's task-agent frontmatter dialect. Use lowercase builtin tool names such
as `read`, `grep`, `glob`, `bash`, `edit`, `write`, `todo`, and `irc`; do not
use retired bridge tools such as `search`, `find`, `ls`, or `intercom`. Multiword keys use
canonical kebab-case forms such as `thinking-level`, `autoload-skills`, and
`read-summarize`.

## MCP access for change request agents

change request builder and reviewer variants use least-privilege MCP selections in the
runtime's native dialect.

- Claude Code variants keep explicit `tools:` allowlists PascalCase builtin
  tool names (`Bash`, `Read`, `Edit`, `Write`, peers) plus scoped selectors
  for three approved servers: GitLab (`mcp__gitlab-mcp__*`),
  `wowtools` (`mcp__wowtools__*`), and Codebase Memory
  (`mcp__codebase-memory-mcp__*`). Do not replace allowlists inherited broad
  tools or `disallowedTools`.
- OMP variants keep explicit lowercase builtin tool lists plus three
  server-scoped MCP wildcard selectors for approved servers: GitLab
  (`mcp__gitlab_mcp_*`), `wowtools` (`mcp__wowtools_*`), and Codebase Memory
  (`mcp__codebase_memory_mcp_*`). Do not add bare `mcp`, `mcp:*`,
  broad `mcp__*`, Claude-style hyphenated selectors `mcp__gitlab-mcp__*`,
  exact per-tool OMP MCP enumerations
  `mcp__gitlab_mcp_get_merge_request`.
- GitLab authority stays in `gitlab`: it remains canonical for GitLab
  transport, MCP-first snippet contracts, the Mutation Guard, SHA/CI guards,
  approval, merge, ready-transition, label, and finish evidence.
- `wowtools` is read/query/domain-data lookup only. It is never GitLab
  authority, CI, gate, approval, merge, ready-transition, label, or finish
  evidence.
- Codebase Memory is structural codebase lookup only. It is never GitLab
  authority, CI, gate, approval, merge, ready-transition, label, or finish
  evidence.

## Agent definition body strategy

Current strategy: do not add a generator or shared-fragment system now. Keep
manual Claude/OMP files so each runtime's dialect stays explicit and reviewable.

Minimize duplicated operational bodies. Runtime-specific frontmatter, tool
names, skill-loading wording, and live-agent coordination stay in each variant.
See the repository [Doc ownership map](../CLAUDE.md#doc-ownership-map) for
canonical workflow and transport owners; agent bodies only keep launch-critical
role boundaries, short core checklists, reporting contracts, and
runtime-specific wording.
Batch coordination stays in [`issue-delivery-loop`](../issue-delivery-loop/SKILL.md).

See the [Check Gate's targeted agent checks](../docs/agents/check-gate.md#targeted-checks)
for the commands guarding the manual dialect strategy.

If generation or shared fragments become worth revisiting, open a dedicated
issue or ADR with migration and check-gate changes instead of mixing it into a
routine agent edit.

## Add a new agent

1. Write `agents/claude/<name>.md` with Claude Code schema.
2. Write `agents/omp/<name>.md` with OMP task-agent schema.
3. Keep body content shared in spirit, but keep runtime-specific coordination and
   frontmatter in the matching dialect file.
4. Point operational procedure to the owners in the repository
   [Doc ownership map](../CLAUDE.md#doc-ownership-map).
5. Run the [targeted agent checks](../docs/agents/check-gate.md#targeted-checks).
6. Run `./install.sh` to surface the agent in installed runtimes.
7. Expect `install.sh` to print a clear `skip:` line when a target runtime or
   variant is missing.

## References

- Motivating case: https://gitlab.example.com/agents/skills/-/merge_requests/31
- Claude Code sub-agent schema: https://code.claude.com/docs/en/sub-agents.md
- Claude Code tools reference: https://code.claude.com/docs/en/tools-reference.md
- OMP task-agent discovery: `omp://task-agent-discovery.md`
- OMP MCP tool names: `omp://mcp-server-tool-authoring.md`
