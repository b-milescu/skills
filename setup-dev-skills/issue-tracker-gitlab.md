# Issue tracker: GitLab

Issues, PRDs, and merge requests for this repo live in GitLab. Use the `glab` CLI from inside this repository clone so commands resolve against the project remote.

Before running issue, MR, CI, note, approval, or merge commands, load `/gitlab-local` and follow its command reference for syntax, flags, JSON output modes, file-backed descriptions/messages, SHA pinning, and known pitfalls. Do not duplicate command snippets in this guide.

## Repo conventions

- GitLab issues are the tracker items for tasks and PRDs.
- GitLab merge requests are the review vehicle for code, docs, and workflow changes.
- Comments are GitLab notes; use `/gitlab-local` for the exact note command shape.
- Labels follow this repo's triage vocabulary; see `docs/agents/triage-labels.md`.
- For machine-readable issue lists and the `-F`/`-O` caveat, use `/gitlab-local` **Snippet: issue-pickup** and its centralized known-pitfalls section; do not restate flag syntax here.
- Infer the project from `git remote -v`; pass an explicit repo target only when `/gitlab-local` says it is needed to avoid host/project ambiguity.
- Branch naming is project policy, not a GitLab schema rename. Declare it in
  `docs/agents/dev-workflows.md` as `project_profile.branch_naming`; keep
  delivery fields named `source_branch` and `target_branch`.

## When a skill says "publish to the issue tracker"

Create a GitLab issue using the workflow and command syntax from `/gitlab-local`. If publishing an approved plan, spec, PRD, or conversation as multiple vertical slices, use `/gitlab-to-issues`.

## When a skill says "fetch the relevant ticket"

Read the referenced GitLab issue, including comments/notes, using `/gitlab-local` for exact command syntax.
