# Repo Scripts

Repo-local maintenance scripts for this skill repository.

## Scripts

| Script | Purpose |
| --- | --- |
| `check.sh` | Canonical local Check Gate wrapper used by `npm run check`. |
| `check-agent-schemas.mjs` | Validates Claude/pi agent frontmatter and dialect-specific schema rules. |
| `check-md-links.mjs` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |

Executable-bit policy: only directly invoked entrypoints keep executable bits.
`scripts/check.sh` is executable because `npm run check` invokes it by path;
helper scripts documented with `bash ...` or `node ...` stay non-executable.

GitLab workflow helper scripts are owned by the `/gitlab-local` skill so installed agent runtimes receive them with the skill. See [`../gitlab-local/scripts/README.md`](../gitlab-local/scripts/README.md).
