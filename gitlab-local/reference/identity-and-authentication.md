# Caller identity and authentication for the finish gate

The deterministic finish gate
[`scripts/gitlab-finish-authority.sh`](../scripts/gitlab-finish-authority.sh)
decides role authority from two identities: the **caller** taking the finish
action and the **author** of the MR being finished. This document defines how the
orchestrating agent obtains, re-verifies, and passes those identities, and why the
git commit author is never used for the self-merge check.

The gate itself is pure-local and makes no network call. Resolving identities is
the **caller's** responsibility before invoking the gate; the gate only validates
and compares the ids it is handed (see the
[authority matrix](authority-matrix.md)).

## Identity lifecycle

1. **At entry.** When the agent begins a finish flow it calls
   `get_current_user()` (the authenticated GitLab user behind the active token).
   That user's id is the `caller_user_id`. If `get_current_user()` fails or
   returns no id, stop and escalate with `identity_unavailable`; do not guess an
   id and do not proceed to the gate.
2. **Immutable for the action.** Once captured, `caller_user_id` is fixed for the
   duration of this finish action. Downstream steps must not re-derive it from a
   different source (CI variables, git config, branch metadata, etc.).
3. **Re-verify immediately before the gate.** Just before calling the gate, the
   agent calls `get_current_user()` again and compares the id to the
   entry-time `caller_user_id`. If the id changed (token swap, session change,
   impersonation), stop and escalate with `identity_changed`; do not run the gate
   with a different identity than the one captured at entry.
4. **MR author id.** `mr_author_id` is read from
   `get_merge_request(...).author.id` for the MR being finished. It is the GitLab
   account that opened the MR.
5. **Pass both ids to the gate.** Invoke
   `gitlab-finish-authority.sh --caller-user-id <id> --mr-author-id <id> ...`.
   The gate blocks empty/missing ids with `reason=invalid_user_id` and blocks
   `caller_user_id == mr_author_id` for any non-`handoff` action with
   `reason=self_merge`.

## The git commit author is NOT the caller

The self-merge check compares **GitLab account ids**, never the git commit author
or committer recorded in the branch history. Reasons:

- Commit author/committer come from local `git config user.email` / `user.name`
  and can be set to anything; they are not authenticated GitLab identities.
- A single MR can contain commits from several authors, or commits authored by
  someone other than the MR opener. The authority decision is about who **opened**
  the MR (`mr_author_id`) versus who is **acting now** (`caller_user_id`), not who
  typed the commits.
- Using the commit author would let a caller bypass no-self-merge by rewriting
  commit author metadata, or trip falsely when a co-author's email appears in
  history.

So `mr_author_id` always comes from `get_merge_request.author.id`, and
`caller_user_id` always comes from `get_current_user()`. The git author is
irrelevant to the self-merge guard.

## Escalation tokens

- `identity_unavailable` — `get_current_user()` failed or returned no id at entry.
- `identity_changed` — the re-verified id before the gate differs from the
  entry-time `caller_user_id`.

Both are caller-side escalations raised before the gate runs. The gate's own
fail-closed reasons (`invalid_user_id`, `self_merge`, `authority`,
`authority_source_mismatch`) are documented in the
[authority matrix](authority-matrix.md).
