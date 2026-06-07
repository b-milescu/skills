# Caller identity and authentication for the finish gate

The deterministic finish gate
[`scripts/gitlab-finish-authority.sh`](../scripts/gitlab-finish-authority.sh)
decides role authority from the caller role, merge-authority claim, action, and
two GitLab identities: the **caller** taking the finish action and the **author**
of the MR being finished. This document defines how the orchestrating agent
obtains, re-verifies, and passes those identities, and why GitLab identity is an
audit/token-stability input rather than the review-independence boundary.

The gate itself is pure-local and makes no network call. Resolving identities is
the **caller's** responsibility before invoking the gate; the gate only validates
and compares the ids it is handed (see the
[authority matrix](authority-matrix.md)) while the broader
[Authority Verification](authority-verification.md) seam combines those ids with
caller role/context, authority sources, restrictions, conflicts, and action
routing.

The caller lifecycle feeds the Caller identity and context phase of the [GitLab Mutation Guard](mutation-guard.md); the guard owns where that phase sits relative to SHA/CI, Authority Verification, fallback, mutation, and post-mutation re-read.

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
   The gate blocks empty/missing ids with `reason=invalid_user_id`. Equal
   `caller_user_id` / `mr_author_id` values are permitted for gate-eligible
   roles; review independence is enforced by the role and Context Firewall.

## Gate input surface

[`scripts/gitlab-finish-authority.sh`](../scripts/gitlab-finish-authority.sh)
accepts exactly seven inputs: five required named inputs plus two optional source
inputs. The caller resolves and passes all of them; the gate only validates and
compares the values it is handed.

| Flag | Required | Meaning |
| --- | --- | --- |
| `--caller-role` | yes | Role taking the action: `builder`, `reviewer`, `authorized-parent`, or `human`. |
| `--caller-user-id` | yes | GitLab account id acting now, from `get_current_user()` (see lifecycle above). |
| `--mr-author-id` | yes | GitLab account id that opened the MR, from `get_merge_request.author.id`. |
| `--merge-authority` | yes | `approval-only`, `reviewer may merge`, `queue auto-merge`, or `human release`. |
| `--action` | yes | Requested finish action: `handoff`, `approve`, `merge`, or `queue-auto-merge`. |
| `--authority-source` | optional | The caller's **declared** provenance string for the `--merge-authority` it passed (where that authority claim came from). |
| `--expected-authority-source` | optional | The provenance string the caller **requires** the declared source to equal before any non-`handoff` finish action is permitted. |

The five required inputs are owned by the [authority matrix](authority-matrix.md)
decision; this section adds only the two optional source inputs and their
fail-closed contract below.

## Authority-source mismatch contract

`--authority-source` and `--expected-authority-source` let the caller pin the
**provenance** of the merge authority it is acting on, separately from the
role × merge-authority × action decision. They drive the
`authority_source_mismatch` fail-closed reason.

- **What each means.** `--authority-source` is the source the caller *declares*
  the `--merge-authority` value came from (for example a stable repo policy
  default, a quoted human MR-comment grant, or a parent-task instruction).
  `--expected-authority-source` is the source the caller *requires* — the
  provenance the merge-authority claim must match to be trustworthy.
- **Who supplies them.** The same orchestrating caller that resolves the
  identities supplies both. The declared source is whatever provenance the caller
  recorded for the merge-authority claim (for example, the MR's Reviewer Lift
  `Merge authority source`); the expected source is the provenance the caller
  independently re-verified just before finishing. Builders never supply these to
  obtain a finish action — the `builder` role is always blocked from
  non-`handoff` actions regardless of source (see the
  [authority matrix](authority-matrix.md)).
- **When `authority_source_mismatch` fires.** The check runs only when
  `--expected-authority-source` is non-empty. If an expected source is declared
  and the passed `--authority-source` does not equal it exactly, the gate blocks
  with exit code `8` and `reason=authority_source_mismatch`, **before** the
  role-authority checks. When `--expected-authority-source` is omitted (empty),
  the gate performs no source comparison and proceeds to the authority checks.
  The comparison is an exact string match, so the caller must normalize the
  declared and expected provenance strings to the same form.
- **How the caller fails closed / escalates.** On exit `8`
  (`authority_source_mismatch`) the caller must make **no** finish mutation: do
  not approve, merge, or queue auto-merge. Re-resolve the merge-authority
  provenance from its canonical source, and re-run the gate only with a freshly
  re-verified, matching `--authority-source`. If the provenance cannot be
  reconciled, stop and escalate to the parent/human with the mismatch rather than
  proceeding on an unverified authority claim.

The `authority_source_mismatch` reason itself is enumerated alongside the gate's
other fail-closed reasons in the [authority matrix](authority-matrix.md); this
document owns the caller contract for the two source inputs, while the matrix owns
the reason within the role × merge-authority × action decision.

## GitLab identity is not the review-independence boundary

The [Authority Verification](authority-verification.md) no-self check compares
roles, sources, and session/context. It does not block solely because two role
executions share a GitLab account.

The deterministic finish gate compares **roles and authority**, not whether two role executions
share a GitLab account. Reasons:

- Agentic review independence comes from fresh session/context separation plus
  the Context Firewall. A builder, parent, planner, or reviser session cannot
  provide gate-eligible review for its own MR, even if it uses a different token.
- A fresh reviewer session may use the same GitLab account/PAT as the builder
  because the GitLab account is a transport identity, not the review context.
- Commit author/committer come from local `git config user.email` / `user.name`
  and can be set to anything; they are not authenticated GitLab identities.

So `mr_author_id` always comes from `get_merge_request.author.id`, and
`caller_user_id` always comes from `get_current_user()` for audit and token
stability. Those ids must be present and stable, but equality between them is not
an approval or merge blocker for a gate-eligible role.

## Escalation tokens

- `identity_unavailable` — `get_current_user()` failed or returned no id at entry.
- `identity_changed` — the re-verified id before the gate differs from the
  entry-time `caller_user_id`.

Both are caller-side escalations raised before the gate runs. The gate's own
fail-closed reasons (`invalid_user_id`, `authority_source_mismatch`, and
`authority`) are documented in the [authority matrix](authority-matrix.md).
