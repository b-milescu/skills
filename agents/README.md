# Agent dialects

Keep agent definitions split by runtime dialect. MR !31 showed why: a shared
agent file can silently lose working tools when one runtime reads another
runtime's frontmatter schema.

## Layout

- `claude/*.md` — Claude Code dialect.
- `omp/*.md` — OMP task-agent dialect for `~/.omp/agent/agents` and project `.omp/agents` discovery.
- Match agent names across both dirs with the same `name:` and the same core
  procedure.
- MR builder/reviewer route basenames are shared across runtime dirs:
  `mr-builder-trivial`, `mr-builder-moderate`, `mr-builder-high-risk`,
  and `mr-reviewer-final`.
- The current runtime resolves the basename in its dialect directory:
  `agents/claude/<route>.md` or `agents/omp/<route>.md`.
- Model pins live in frontmatter, not route names; provider pins live there too.
  Route basenames stay distinct from role/mode labels such as
  `child mr-builder` and `mr-reviewer`.
- Missing route has no fallback, shim, old-filename, or cross-runtime
  substitute; treat it as route-unavailable. Any other agent still requires
  counterpart in both dialects.

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
as `read`, `search`, `find`, `bash`, `edit`, `write`, `todo`, and `irc`; do not
use retired bridge tools such as `grep`, `ls`, or `intercom`. Multiword keys use
canonical kebab-case forms such as `thinking-level`, `autoload-skills`, and
`read-summarize`.

## MCP access for MR agents

MR builder and reviewer variants use least-privilege MCP selections in the
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

Minimize duplicated operational bodies:

- Runtime dialect stays in the variant file: frontmatter schema, tool names,
  skill-loading wording, and live-agent coordination are runtime-specific.
- `start-build` owns builder workflow, Review Packet templates, TDD handoff,
  and parent-owned review-gate policy.
- `start-review` owns reviewer flow, Review Report format, authority handling,
  and SHA/CI guard policy.
- `gitlab` owns MCP-first GitLab transport contracts, guarded `glab`
  fallback syntax, JSON flag caveats, snippets, and SHA-guarding. Agent files
  should point to it instead of copying commands.
- `issue-delivery-loop` owns batch delivery coordination, WIP limits, parent
  spot-checks, revision routing, and batch metrics. Agent files should point
  to it instead of copying coordinator-loop bodies.
- Agent bodies may keep launch-critical role boundaries, short core checklists,
  reporting contracts, and runtime-specific wording. Move long operational
  procedure changes to the canonical skills first, then update agent pointers.

Drift checks guard this manual strategy:

- `npm run check:agents-schema` validates dialect frontmatter, tool naming, MCP
  allowlists, and retired bridge wording.
- `bash agents/check.sh` validates agent name parity, canonical
  `start-build`/`start-review` and `gitlab` pointers, Reviewer Lift and
  Review Report duplicate structures, and required external skill dependencies.

If generation or shared fragments become worth revisiting, open a dedicated
issue or ADR with migration and check-gate changes instead of mixing it into a
routine agent edit.

## Add a new agent

1. Write `agents/claude/<name>.md` with Claude Code schema.
2. Write `agents/omp/<name>.md` with OMP task-agent schema.
3. Keep body content shared in spirit, but keep runtime-specific coordination and
   frontmatter in the matching dialect file.
4. Point operational procedure back to canonical skills such as `start-build`,
   `start-review`, and `gitlab` rather than copying long bodies.
5. Run `npm run check:agents-schema` to catch frontmatter/schema/tool-casing
   drift before install or review.
6. Run `bash agents/check.sh` to catch parity and canonical-pointer drift.
7. Run `./install.sh` to surface the agent in installed runtimes.
8. Expect `install.sh` to print a clear `skip:` line when a target runtime or
   variant is missing.

## References

- Motivating case: https://gitlab.example.com/agents/skills/-/merge_requests/31
- Claude Code sub-agent schema: https://code.claude.com/docs/en/sub-agents.md
- Claude Code tools reference: https://code.claude.com/docs/en/tools-reference.md
- OMP task-agent discovery: `omp://task-agent-discovery.md`
- OMP MCP tool names: `omp://mcp-server-tool-authoring.md`
