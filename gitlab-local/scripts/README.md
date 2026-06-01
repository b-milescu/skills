# GitLab Workflow Helpers

Optional shell helpers wrap accepted `/gitlab-local` snippets and read-only
verification reports for repeatable parent-orchestrator, finisher, or verifier
flows. They use `glab`, `git`, and Node.js for local JSON parsing. They do not
replace `glab`, the mandatory review gate, project policy, or role authority.

## Helpers

| Helper | Source contract | Guard summary | Regression coverage |
| --- | --- | --- | --- |
| `gitlab-ci-watch.sh` | [`gitlab-local` Snippet: ci-watch-sha-pinned](../SKILL.md#snippet-ci-watch-sha-pinned) | Re-reads MR metadata, requires the MR head to match the reviewed SHA, and only passes green CI when the pipeline SHA matches that reviewed SHA. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-finish-mr.sh` | [`gitlab-local` Snippet: finish-mr-authority-aware](../SKILL.md#snippet-finish-mr-authority-aware) | Blocks stale heads, stale/red/missing CI, unknown MR state, missing or unknown merge authority, and dirty worktree cleanup. Builder callers always get a handoff; they cannot approve, merge, or queue auto-merge. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-post-merge-snapshot.sh` | [`start-build` Post-merge verifier recipe](../../start-build/reference/post-merge-verifier.md) | Emits `post_merge_snapshot.kind=post-merge-snapshot` from read-only MR/issue/default-branch/source-branch checks, explicit reviewed/merge/squash containment, documented non-mutating validation, and pending items. It reports closure/cleanup pending instead of acting. | `../../tests/gitlab-workflow-helpers.sh` |
| `gitlab-wrappers.sh` | `issue-note-create`, `mr-note-create`, `label-reconcile`, `safe-mr-json`, and `auto-merge-api-fallback` snippets | Keeps issue/MR notes split and file-backed; reconciles labels without replacement assumptions; validates decision-grade MR JSON; preserves SHA/CI/authority/project-binding guards for the known auto-merge 405 API fallback. | `../../tests/gitlab-workflow-helpers.sh` |

Tests in `../../tests/gitlab-workflow-helpers.sh` use fake `glab` and `git`
binaries, so the regression suite performs no live GitLab mutation. The snapshot
coverage verifies merged, closure-pending, branch-cleanup-pending,
retained-by-policy/unknown, stale/missing containment, and validation not-run
cases without approving, merging, queueing auto-merge, force-closing issues,
deleting branches, releasing, deploying, or mutating product/runtime systems.
The wrapper coverage also verifies fake issue/MR notes, label updates, MR JSON,
and auto-merge fallback paths without changing live labels or MRs. The alignment test
in `../../tests/gitlab-local-split-snippets.sh` verifies `/gitlab-local` keeps
stable snippet names while pointing long helper bodies here and to script
sources.

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
