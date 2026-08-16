# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all issue operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc or file for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments` and include labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments` with appropriate `--label` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`.
- **Close**: `gh issue close <number> --comment "..."`.

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Approved-plan publishing

After `/forge preflight`, use `/plan-to-issues` for approved-plan breakdowns. `/gitlab` stays GitLab-only transport.

## When a skill says "publish to the issue tracker"

Create a GitHub issue. If publishing an approved plan as multiple vertical slices, use `/plan-to-issues` after `/forge preflight`.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.
