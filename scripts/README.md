# GitLab Workflow Helpers

Optional shell helpers wrap the accepted `/gitlab-local` snippets for repeatable
parent-orchestrator or finisher flows. They do not replace `glab`, the mandatory
review gate, or project policy.

## Helpers

- `gitlab-ci-watch.sh` wraps the SHA-pinned CI watcher behavior from
  [`gitlab-local` Snippet: ci-watch-sha-pinned](../gitlab-local/SKILL.md#snippet-ci-watch-sha-pinned).
  It re-reads MR metadata, requires the MR head to match the reviewed SHA, and
  only passes green CI when the pipeline SHA matches that reviewed SHA.
- `gitlab-finish-mr.sh` wraps the authority-aware finish behavior from
  [`gitlab-local` Snippet: finish-mr-authority-aware](../gitlab-local/SKILL.md#snippet-finish-mr-authority-aware).
  It blocks stale heads, stale/red/missing CI, unknown MR state, missing or
  unknown merge authority, and dirty worktree cleanup. Builder callers always
  get a handoff; they cannot approve, merge, or queue auto-merge.

Tests in `tests/gitlab-workflow-helpers.sh` use fake `glab` and `git` binaries,
so the regression suite performs no live GitLab mutation.

## When to prefer raw `gitlab-local` snippets

Use the raw snippets instead of helpers when:

- the local `glab` version or GitLab response shape differs from the helper's
  supported path;
- the flow needs a human waiver, project-specific policy, or variant not encoded
  in these generic helpers;
- you are diagnosing GitLab behavior and need each command visible step by step;
- you are updating accepted workflow behavior in `gitlab-local` itself;
- the caller lacks clear approval/merge authority.

Use helpers when the accepted snippet behavior already fits and you want a
repeatable command with fail-closed guardrails.
