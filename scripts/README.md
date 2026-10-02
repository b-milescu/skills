# Repo Scripts

Repo-local maintenance scripts for this skill repository.

## Scripts

| Script | Purpose |
| --- | --- |
| `check.sh` | Canonical local Check Gate wrapper used by `npm run check`. |
| `check-agent-schemas.mjs` | Validates Claude/OMP agent frontmatter and dialect-specific schema rules. |
| `check-md-links.mjs` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |

Executable-bit policy: only directly invoked entrypoints keep executable bits.
`scripts/check.sh` is executable because `npm run check` invokes it by path;
helper scripts documented with `bash ...` or `node ...` stay non-executable.

Installed workflow gate helpers use the unmodified js-yaml 4.1.1 ESM distribution
at `start-build/scripts/vendor/js-yaml.mjs`, with its adjacent `js-yaml.LICENSE`.
This static dependency closes native OMP Git installs without a package hook;
root `package.json` remains development/native dependency metadata, not a release.

