# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the native GitHub
transport from `skill://forge/reference/github.md` for every issue operation;
`gh` is one of the native transports it names. Infer the repo from
`git remote -v`; `gh` does this automatically inside a clone.

## Tracker shape

- An issue carries title, body, labels, and comments. Read comments with the
  issue; they hold the current discussion an agent must reconcile.
- Multi-line bodies go through a file or heredoc, never an inline quoted blob.
- Labels are applied to an existing issue from the repo's triage-label doc, not
  invented at create time.

## Approved-plan publishing

After `/forge preflight`, use `/plan-to-issues` for approved-plan breakdowns. `/gitlab` stays GitLab-only transport.

## When a skill says "publish to the issue tracker"

Create a GitHub issue. If publishing an approved plan as multiple vertical slices, use `/plan-to-issues` after `/forge preflight`.

## When a skill says "fetch the relevant ticket"

Read the issue with its comments through the native GitHub transport.
