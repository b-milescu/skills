# Agent dialects

Keep agent definitions split by runtime dialect. MR !31 showed why: a shared
agent file can silently lose working tools when one runtime reads another
runtime's frontmatter schema.

## Layout

- `claude/*.md` — Claude Code dialect.
- `pi/*.md` — pi dialect.
- Match agent names across both dirs with the same `name:` and the same core
  procedure.

## Claude Code variant

Use Claude Code's documented sub-agent frontmatter only. Use PascalCase tool
names from the tools reference, for example `Bash`, `Read`, `Edit`, and `Write`.
Keep Claude-only fields such as `effort:` here.

Remove pi bridge language from Claude bodies: no `contact_supervisor`, no
`intercom`, and no `Supervisor coordination` section. Add explicit
anti-fabrication reporting rules when the agent interacts with GitLab or other
remote state.

## pi variant

Use pi's agent frontmatter dialect. Use lowercase tool names and pi-specific
fields such as intercom bridge coordination fields. Keep pi-only bridge wording
here, not in Claude Code variants.

## Add a new agent

1. Write `agents/claude/<name>.md` with Claude Code schema.
2. Write `agents/pi/<name>.md` with pi schema.
3. Keep body content shared in spirit, but keep runtime-specific coordination and
   frontmatter in the matching dialect file.
4. Run `npm run check:agents-schema` to catch frontmatter/schema/tool-casing
   drift before install or review.
5. Run `./install.sh` to surface the agent in installed runtimes.
6. Expect `install.sh` to print a clear `skip:` line when a target runtime or
   variant is missing.

## References

- Motivating case: https://gitlab.example.com/agents/skills/-/merge_requests/31
- Claude Code sub-agent schema: https://code.claude.com/docs/en/sub-agents.md
- Claude Code tools reference: https://code.claude.com/docs/en/tools-reference.md
- pi agent frontmatter: `~/.pi/agent/npm/node_modules/pi-subagents/README.md`
  § "Agent frontmatter"
