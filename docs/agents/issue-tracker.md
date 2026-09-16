# Issue tracker: GitLab

Issues, PRDs, and merge requests for this repo live on the self-hosted GitLab instance at `gitlab.example.com` in project `agents/skills` (`https://gitlab.example.com/agents/skills`).

Use `/gitlab` from inside this repository clone so GitLab API actions follow its MCP-first transport order; guarded `glab` fallback is second and only under the conditions `/gitlab` documents. Do not duplicate transport snippets in this guide.

This repo's tracker path, host, project path, and label-profile ref are verified against `setup-dev-skills/reference/project-profile-facts.json`; generated target repos may use different repo-relative Agent Setup Doc paths.

## Repo conventions

- GitLab issues are the tracker items for tasks and PRDs.
- GitLab merge requests are the review vehicle for code, docs, and workflow changes.
- Comments are GitLab notes; use `/gitlab` for the exact MCP/fallback note contract.
- Labels follow this repo's triage vocabulary; see `docs/agents/triage-labels.md`.
- For machine-readable issue lists and pagination caveats, use `/gitlab` **Snippet: issue-pickup** and its centralized known-pitfalls section; do not restate syntax here.
- Infer the project from `git remote`; pass an explicit project/repo target only when `/gitlab` says it is needed to avoid host/project ambiguity.
- Branch naming is project policy, not a GitLab schema rename. This repo declares
  it in [`docs/agents/dev-workflows.md`](dev-workflows.md#branch-naming) as
  `project_profile.branch_naming`; delivery fields remain `source_branch` and
  `target_branch`.

## When a skill says "publish to the issue tracker"

Create a GitLab issue on `gitlab.example.com/agents/skills` using the workflow and transport contract from `/gitlab`. If publishing an approved plan, spec, PRD, or conversation as multiple vertical slices, use `/plan-to-issues`.

## When a skill says "fetch the relevant ticket"

Read the referenced GitLab issue, including comments/notes, using `/gitlab` for the exact MCP primary / guarded fallback contract.

## Reconcile on unblock

When a merge closes an issue that an open issue names as a blocker or ordering constraint, update or strike that dependent issue's `Blocked by` / `Dependencies` text in the same step, so the next reader sees current tracker state instead of an expired constraint. This reconcile-on-unblock rule is bounded to that transition; it grants no licence to rewrite issue bodies otherwise.
