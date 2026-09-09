# compaction-index

OMP extension that keeps a compact index of loaded skills available after OMP
compaction, so a parent delivery session does not re-read full `skill://`
bodies on the next turn (#444; decision context #440 note 48376, host 1).

## Capability verification (local OMP 18.1.15, `@oh-my-pi/pi-coding-agent`)

- `session_before_compact` exists (`src/extensibility/shared-events.ts`) but its
  result (`cancel`, `compaction`) can only cancel or replace the whole
  compaction — it cannot inject content.
- The content-injection equivalent is the `session.compacting` extension event:
  handler results may return `context?: string[]` ("Additional context lines to
  include in summary", `src/extensibility/shared-events.ts`), and the session
  maintenance layer appends those lines to the compaction summary context
  (`src/session/session-maintenance.ts`).
- Extensions load from `~/.omp/agent/extensions/*.ts|*.js`
  (`src/extensibility/extensions/loader.ts`, `isExtensionFile` /
  `discoverExtensionsInDir`; the path is also named in `src/sdk.ts`).

## Contract

On `session.compacting`, the extension scans the messages being summarized for
`skill://<name>` reads and re-injects one index line per skill: name,
`skill://` URI, and the one-line `description:` from the installed
`SKILL.md` frontmatter. Never full skill bodies — bodies stay re-readable on
demand. Each entry is capped at 2 KiB and the whole re-injected block at
16 KiB (truncating with a notice), so the measured worst case from #440
(1.07M chars of `skill://` re-reads after compaction) cannot recur here.

`COMPACT_INDEX_SKILL_ROOT` overrides the skill directory for tests.

## Surfacing

`install.sh` links `compaction-index/extensions/*.js` into
`~/.omp/agent/extensions/`, skipping and reporting when `~/.omp/agent` is
absent, exactly like the agent targets. Regression:
`tests/compaction-index.sh` (dedupe, size caps, no full bodies, installer
link/skip paths).
