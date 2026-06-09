# Repo Scripts

Repo-local maintenance scripts for this skill repository.

## Scripts

| Script | Purpose |
| --- | --- |
| `check.sh` | Canonical local Check Gate wrapper used by `npm run check`. |
| `check-agent-schemas.mjs` | Validates Claude/pi agent frontmatter and dialect-specific schema rules. |
| `check-md-links.mjs` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| `list-prompt-drift-markdown.sh` | Enumerates Markdown files for prompt-drift checks: normal repo-root worktrees use `git ls-files` so scans stay limited to tracked Markdown, while fixture or temp-copied repos without matching Git metadata use a conservative `find` fallback that prunes local artifact directories. |

Executable-bit policy: only directly invoked entrypoints keep executable bits.
`scripts/check.sh` is executable because `npm run check` invokes it by path;
helper scripts documented with `bash ...` or `node ...` stay non-executable.

GitLab workflow helper scripts are owned by the `/gitlab` skill so installed agent runtimes receive them with the skill. See [`../gitlab/scripts/README.md`](../gitlab/scripts/README.md).
