# Issue tracker: Local Markdown

Issues and PRDs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`.
- The PRD is `.scratch/<feature-slug>/PRD.md`.
- Implementation issues are `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`.
- Triage state is recorded as a `Status:` line near the top of each issue file; see `triage-labels.md` for role strings.
- Comments and conversation history append to the bottom of the file under `## Comments`.

## GitLab-only workflow note

`/gitlab`, `/gitlab-to-issues`, `/start-build`, and `/start-review` are GitLab-specific. Do not use them for this local tracker unless the user explicitly switches to GitLab. For issue breakdowns, use `/to-issues` if installed; otherwise follow this repo's local-markdown workflow manually.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` and create the directory if needed.

## When a skill says "fetch the relevant ticket"

Read the referenced markdown file. The user will normally pass the path or issue number directly.
