# Caller identity and authentication for the finish gate

MCP `finish_merge_request` uses the caller role, merge-authority claim, requested action, and two GitLab identities: the **caller** taking the action and the **author** who opened the MR. GitLab identity is audit/token-stability evidence, not the review-independence boundary; local commit author/committer values are unauthenticated and never identity evidence. [Authority Verification](authority-verification.md) adds context, sources, restrictions, conflicts, and routing; the [GitLab Mutation Guard](mutation-guard.md) owns their place in the sequence.

## Identity lifecycle

1. **Capture at entry.** Call `get_current_user()` and store its id as `caller_user_id`. Failure or no id is `identity_unavailable`; never guess.
2. **Keep immutable.** Do not re-derive it from CI variables, Git config, branch metadata, or any other source during the action.
3. **Re-verify immediately before finish.** Call `get_current_user()` again. A different id (token/session/impersonation change) is `identity_changed`; stop without finishing.
4. **Read the MR author.** Set `mr_author_id` from `get_merge_request(...).author.id`.
5. **Pass both ids.** Empty values fail closed. Equality is permitted for gate-eligible roles because role and the Context Firewall enforce review independence.

## Gate input surface

`finish_merge_request` requires caller role, caller user id, MR author id, merge authority, and action; empty ids fail closed. Two optional provenance inputs: the **authority source** recorded for the merge-authority claim, and the **expected authority source** independently re-verified before a non-`handoff` action. Typical sources are a stable rulebook default, a quoted human MR-comment grant, or a parent instruction. The declared value comes from the recorded claim (for example Reviewer Lift); the expected value is freshly re-verified immediately before finish.

When expected authority source is non-empty, comparison is exact. A mismatch blocks with `authority_source_mismatch` before role-authority checks. An empty expected source skips only this comparison; all authority checks still run. Normalize both provenance strings to the same form.

Builders cannot use these fields to gain finish authority: the `builder` role remains blocked from every non-`handoff` action. On mismatch, make no approval, merge, or auto-merge mutation. Re-resolve the canonical provenance and retry only with a fresh exact match; if it cannot be reconciled, escalate to the parent/human.
