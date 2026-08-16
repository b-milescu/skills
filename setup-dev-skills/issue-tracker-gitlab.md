# Issue tracker: GitLab

Issues, PRDs, and merge requests for the target repo live in GitLab. Use `/gitlab` from inside the target repository clone so GitLab API actions follow MCP-first transport order; guarded `glab` fallback is second and only for documented fallback/helper/troubleshooting conditions.

Before fallback issue, MR, CI, note, approval, or merge commands, invoke `/gitlab` and follow its help-first flag checks, JSON output modes, file-backed descriptions/messages, SHA pinning, and known pitfalls. Do not duplicate transport snippets in this guide. Use `setup-dev-skills/reference/project-profile-facts.json` to instantiate the target repo's tracker doc path, label vocabulary ref, branch naming ref, and runtime `skill://` resource refs.

## Repo conventions

- GitLab issues are the tracker items for tasks and PRDs.
- GitLab merge requests are the review vehicle for code, docs, and workflow changes.
- Comments are GitLab notes; use `/gitlab` for the exact MCP/fallback note contract.
- Labels follow the target repo's live triage vocabulary; use the `label_profile_ref` and Triage Role mapping recorded in the project-profile facts and the generated triage-labels doc.
- For machine-readable issue lists and the MCP list-pagination / `glab` `-F`/`-O` caveats, use `/gitlab` **Snippet: issue-pickup** and its centralized known-pitfalls section; do not restate syntax here.
- Infer the project from `git remote`; pass an explicit project/repo target only when `/gitlab` says it is needed to avoid host/project ambiguity.
- Branch naming is project policy, not a GitLab schema rename. Declare it in
  the target repo's Dev Workflow doc as `project_profile.branch_naming`; keep
  delivery fields named `source_branch` and `target_branch`.

## When a skill says "publish to the issue tracker"

Create a GitLab issue using the workflow and transport contract from `/gitlab`. If publishing an approved plan, spec, PRD, or conversation as multiple vertical slices, use `/plan-to-issues`.

## When a skill says "fetch the relevant ticket"

Read the referenced GitLab issue, including comments/notes, using `/gitlab` for the exact MCP primary / guarded fallback contract.
