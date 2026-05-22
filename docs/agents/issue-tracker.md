# Issue tracker: GitLab

Issues and PRDs for this repo live as GitLab issues on the self-hosted instance at `gitlab.example.com` (project: `agents/skills`). Use the [`glab`](https://gitlab.com/gitlab-org/cli) CLI for all operations.

Before running any `glab` command, load the `/local-gitlab` skill — it centralises the preflight check, canonical command snippets (file-backed `--description`/`--message`, `-F json` projections, `--sha` pinning), and known flag pitfalls. Don't hand-roll flags; defer to the skill's snippets.

## Conventions

- **Create an issue**: `glab issue create --title "..." --description "..."`. Use a heredoc or `--description -` for multi-line bodies. Never paste secrets or tokens.
- **Read an issue**: `glab issue view <number> --comments`. Use `-F json` for machine-readable output.
- **List issues**: `glab issue list -F json` with appropriate `--label` filters.
- **Comment on an issue**: `glab issue note <number> --message "..."`. GitLab calls comments "notes".
- **Apply / remove labels**: `glab issue update <number> --label "..."` / `--unlabel "..."`. Multiple labels can be comma-separated or by repeating the flag.
- **Close**: `glab issue close <number>`. `glab issue close` does not accept a closing comment, so post the explanation first with `glab issue note <number> --message "..."`, then close.
- **Merge requests**: GitLab calls PRs "merge requests". Use `glab mr create`, `glab mr view`, `glab mr note`, etc. — the same shape as `gh pr ...` with `mr` in place of `pr` and `note`/`--message` in place of `comment`/`--body`. Pin approvals and merges with `--sha`.

Infer the repo from `git remote -v` — `glab` does this automatically when run inside a clone of this repo.

## When a skill says "publish to the issue tracker"

Create a GitLab issue on `gitlab.example.com/agents/skills`.

## When a skill says "fetch the relevant ticket"

Run `glab issue view <number> --comments`.
