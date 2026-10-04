# Repo Scripts

Repo-local maintenance scripts for this skill repository.

## Scripts

| Script | Purpose |
| --- | --- |
| `check.sh` | Canonical local Check Gate wrapper used by `bun run check`. |
| `check-agent-schemas.mjs` | Validates Claude/OMP agent frontmatter and dialect-specific schema rules. |
| `check-md-links.mjs` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |

Executable-bit policy: only directly invoked entrypoints keep executable bits.
`scripts/check.sh` is executable because `bun run check` invokes it by path;
helper scripts documented with `bash ...` or `bun ...` stay non-executable.

Every repo `.mjs` (helpers, scripts and tests) imports only `node:` builtins or
relative paths; `tests/skill-stack-agnostic.mjs` enforces it. YAML parsing uses the
unmodified js-yaml 4.1.1 ESM distribution at `start-build/scripts/vendor/js-yaml.mjs`,
with its adjacent `js-yaml.LICENSE`. This static dependency closes native OMP Git
installs without a package hook; root `package.json` carries only the Markdown
linter and remains development metadata, not a release.

