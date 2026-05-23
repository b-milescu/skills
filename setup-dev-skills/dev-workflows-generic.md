# Dev Workflows

This repo is not configured for GitLab-backed dev workflows.

## GitLab-only skills

- **`/gitlab-local`** — only for GitLab repositories or GitLab mirrors.
- **`/gitlab-to-issues`** — only for publishing approved plans/specs/PRDs as GitLab issues.
- **`/start-build`** — only for implementing GitLab issues and opening GitLab merge requests.
- **`/start-review`** — only for reviewing GitLab merge requests.

Do not use those GitLab-specific skills for this repo's configured issue tracker unless the user explicitly switches to GitLab.

## Alternatives

- For issue breakdowns, use `/to-issues` if installed; otherwise follow this repo's tracker-specific workflow manually.
- For implementation and review, follow this repo's `CLAUDE.md` / `AGENTS.md`, issue tracker docs, and project-specific commands.
- Project docs in `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
