# Caller identity and authentication for the finish gate

MCP `finish_merge_request` uses the caller role, merge-authority claim, requested action, and two GitLab identities: the **caller** taking the action and the **author** who opened the MR. This reference defines how callers obtain and stabilize those identities. GitLab identity is audit/token-stability evidence, not the review-independence boundary.

The caller resolves identity before invoking the tool; the [authority matrix](authority-matrix.md) validates the supplied ids and role × authority × action decision. [Authority Verification](authority-verification.md) adds context, sources, restrictions, conflicts, and routing. Their placement in the full mutation sequence is owned by the [GitLab Mutation Guard](mutation-guard.md).

## Identity lifecycle

1. **Capture at entry.** Call `get_current_user()` and store its id as `caller_user_id`. Failure or no id is `identity_unavailable`; never guess.
2. **Keep immutable.** Do not re-derive it from CI variables, Git config, branch metadata, or any other source during the action.
3. **Re-verify immediately before finish.** Call `get_current_user()` again. A different id (token/session/impersonation change) is `identity_changed`; stop without finishing.
4. **Read the MR author.** Set `mr_author_id` from `get_merge_request(...).author.id`.
5. **Pass both ids.** Empty values fail closed. Equality is permitted for gate-eligible roles because role and the Context Firewall enforce review independence.

## Gate input surface

The [authority matrix](authority-matrix.md) owns the five required inputs: caller role, caller user id, MR author id, merge authority, and action. The caller supplies them and `finish_merge_request` validates them.

This reference adds two optional provenance inputs:

| Input | Meaning |
| --- | --- |
| authority source | Source recorded for the merge-authority claim. |
| expected authority source | Independently re-verified source that the declared source must equal before a non-`handoff` action. |

## Authority-source mismatch contract

The caller supplies both values. Typical sources are a stable rulebook default, a quoted human MR-comment grant, or a parent instruction. The declared value comes from the recorded claim (for example Reviewer Lift); the expected value is freshly re-verified immediately before finish.

When expected authority source is non-empty, comparison is exact. A mismatch blocks with `authority_source_mismatch` before role-authority checks. An empty expected source skips only this comparison; all authority checks still run. Normalize both provenance strings to the same form.

Builders cannot use these fields to gain finish authority: the `builder` role remains blocked from every non-`handoff` action. On mismatch, make no approval, merge, or auto-merge mutation. Re-resolve the canonical provenance and retry only with a fresh exact match; if it cannot be reconciled, escalate to the parent/human.

The [authority matrix](authority-matrix.md) enumerates `authority_source_mismatch` among the gate reasons; this document owns the caller contract for its two source inputs.

## GitLab identity is not the review-independence boundary

Authority Verification's no-self check uses role, source, and session/context. A builder, parent, planner, or reviser session cannot provide gate-eligible review for its own MR, even with a different token. A fresh reviewer may share the builder's GitLab account/PAT because the account is transport identity, not review context. Local commit author/committer values are unauthenticated and irrelevant.

Therefore `mr_author_id` always comes from `get_merge_request.author.id`, and `caller_user_id` from `get_current_user()`. Both must be present and stable; equality alone is not an approval or merge blocker for a gate-eligible role.

## Escalation tokens

- `identity_unavailable` — `get_current_user()` failed or returned no id at entry.
- `identity_changed` — the pre-finish id differs from entry-time `caller_user_id`.

These arise before the gate. The matrix owns gate reasons `invalid_user_id`, `authority_source_mismatch`, and `authority`.
