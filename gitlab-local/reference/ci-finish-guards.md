# GitLab CI-watch & finish guard mechanics

Relocated mechanics for the [`ci-watch-sha-pinned`](../SKILL.md#snippet-ci-watch-sha-pinned)
and [`finish-mr-authority-aware`](../SKILL.md#snippet-finish-mr-authority-aware)
snippets. Full command ownership and help-first discipline stay in
[`gitlab-local/SKILL.md`](../SKILL.md); apply the
[`help-first` rule](../SKILL.md#help-first-rule) before running any flagged CLI
command.

This card owns the **glab mechanics** for those two snippets (poll loop, SHA
pinning, fail-closed output shape, finish guard order). It does **not** own the
**verdict-classification** or **merge/authority** policy: those are restated by
pointer only, because `gitlab-local/` = mechanics and `start-build/` +
`start-review/` = merge/CI/authority policy (see the `CLAUDE.md` doc-ownership
map). The 7 polling/SHA rules and 8 finish guard/authority steps below are
load-bearing safety invariants relocated here verbatim — do not delete or weaken
them.

## CI verdict mechanics (`ci-watch-sha-pinned`)

Use when a parent orchestrator, reviewer, or authorized finisher needs a CI
verdict for the exact MR head that was reviewed. Builders may record this output
in a Review Packet, but CI success does not grant builder approval or merge
authority.

Polling and SHA rules:

1. Re-read `glab mr view "$mr_iid" -F json` on every poll; do not rely on
   `glab mr list` for decision-grade data.
2. Fail immediately if MR `.sha` differs from `reviewed_sha`; the review is
   stale and a new review is needed.
3. Prefer MR `.pipeline`; use `glab ci status --branch "$source_branch" -F json`
   only when MR metadata has no attached pipeline yet or to print job progress.
   Do not use `glab ci status --mr`.
4. Classify the pipeline verdict (success / red / canceled / skipped / stale /
   missing / pending semantics, including the green-only-when `.sha ==
   reviewed_sha` and `.status == success` rule, and protected pending-auto-merge
   handling) with the canonical
   [CI decision table in `start-review/REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
5. Stale CI for any other SHA never passes. Continue polling until the expected
   SHA appears or the timeout expires; final output must say `stale_ci` or
   `timeout` and include the last observed SHA/status.
6. Timeout output is non-zero and includes last MR pipeline and branch/job
   summary so the caller can distinguish "no pipeline yet" from stale CI.
7. If adapting raw commands instead of the helper, keep every polling/SHA rule
   above, run help-first for `glab mr view` and `glab ci status`, and fail closed
   on missing, stale, red, or SHA-mismatched CI. Machine output fields should
   include `mr`, `expected_sha`, `observed_sha`, `pipeline_id`, `status`, `url`,
   failed/running job names when available, and
   `result: pass | fail | head_changed | stale_ci | timeout`.

## Finish guard/authority mechanics (`finish-mr-authority-aware`)

Use after an independent review decision, not from a child builder. A builder may
prepare or report the inputs, but must not approve, merge, queue auto-merge, or
pretend to complete the review gate. Only a reviewer performing the review flow
or an explicitly authorized parent/human may run the approve/merge steps.

Guard and authority order:

1. Run the help-first checks for every flagged command in the chosen path.
2. Re-read `glab mr view "$mr_iid" -F json`; require current `.sha` to equal
   `reviewed_sha` before approval, merge, auto-merge, or cleanup.
3. Require CI evidence for `reviewed_sha` (`.pipeline.sha == reviewed_sha` and
   `.pipeline.status == success`), classified by the
   [CI decision table in `start-review/REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table).
   Red, canceled, skipped, missing, or stale CI blocks finish unless an
   authorized human waiver is recorded in the MR.
4. Apply the caller-role and merge-authority matrix (`approval-only` /
   `reviewer may merge` / `queue auto-merge` / `human release`) per the canonical
   owners: [`start-build/SAFETY.md` authority / no-self-merge](../../start-build/SAFETY.md#non-negotiables)
   and [`start-review/REVIEW-FLOW.md` CI & finish policy](../../start-review/REVIEW-FLOW.md#ci-and-open-question-decision-tables).
   A `builder` caller role always stops with a handoff and never approves,
   merges, queues, or deletes a remote branch.
5. Fetch the default branch only after a merge/queue action or when producing a
   final status. For any local cleanup after a merge, use `git fetch origin`,
   then fast-forward the local default only in a clean checkout where that branch
   can be checked out safely. Before removing local worktrees or deleting local
   source branches, verify the reviewed SHA is an ancestor of the fast-forwarded
   local default, or verify an equivalent MR `merge_commit_sha` /
   `squash_commit_sha` is an ancestor when the project uses merge commits or
   squash merges. If no SHA check passes, retain local cleanup targets and report
   cleanup pending instead of emitting only a warning.
6. Verify linked issue state with `glab issue view "$issue_iid" -F json` when an
   issue IID is known. Report `closure_pending` rather than force-closing unless
   the workflow explicitly told you to close the issue.
7. Remove a worktree only when `git -C "$worktree_path" status --porcelain` is
   empty, branch push/merge state is known, and the default-branch safety check
   above has passed for post-merge local cleanup. Delete local/remote source
   branches only after merge or auto-merge policy permits it; prefer GitLab's
   remove-source-branch setting when available.
8. Emit final status: MR IID/URL, reviewed SHA, CI status/SHA, action taken,
   issue state, cleanup result, and blocker reason if any. If adapting raw
   commands instead of the helper, keep this guard order, run help-first for
   every flagged `glab` command, perform exactly one finish action, keep
   approval/merge SHA-bound, and preserve builder handoff semantics. Machine
   output should use the same facts as the human line, for example
   `result: merged | auto_merge_queued | handoff | blocked`, plus `blocker` when
   non-success output requires parent/human action.

## Fallback to full gitlab-local

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) and live `--help` when `glab`
flag/JSON drift appears, a project-specific policy or human waiver is involved,
or a card and the full reference conflict. The full reference plus live help
wins. For verdict-classification and authority questions, the canonical owners
are [`start-review/REVIEW-FLOW.md`](../../start-review/REVIEW-FLOW.md#ci-decision-table)
and [`start-build/SAFETY.md`](../../start-build/SAFETY.md#non-negotiables).
