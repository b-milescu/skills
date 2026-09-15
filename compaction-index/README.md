# compaction-index

OMP extension that keeps a compact index of loaded skills available after OMP
compaction, so a parent delivery session does not re-read full `skill://`
bodies on the next turn (#444; decision context #440 note 48376, host 1).

## Contract

On `session.compacting`, the extension scans the messages being summarized for
`skill://<name>` reads and re-injects one index line per skill: name,
`skill://` URI, and the one-line `description:` from the installed
`SKILL.md` frontmatter. Never full skill bodies — bodies stay re-readable on
demand. Each entry is capped at 2 KiB and the whole re-injected block at
16 KiB, truncating with a notice, so post-compaction re-reads stay bounded.

`COMPACT_INDEX_SKILL_ROOT` overrides the skill directory for tests.

## Surfacing

`install.sh` links `compaction-index/extensions/*.js` into
`~/.omp/agent/extensions/`, skipping and reporting when `~/.omp/agent` is
absent, exactly like the agent targets. Regression:
`tests/compaction-index.sh` (dedupe, size caps, no full bodies, installer
link/skip paths).
