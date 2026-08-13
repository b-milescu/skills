# GitHub Transport

Use only after `preflight` binds GitHub host, owner/repository, and default branch.
Use native REST/GraphQL or `gh`; add no SDK. Bind a pull request to `headRefOid`.

## Snapshot

- Read every paginated file, review, review thread, and required CI context.
  Missing pages, GitHub's 3,000-file REST cap, or incomplete-pagination evidence
  fail closed.
- Read Checks and classic statuses for the exact `headRefOid`; null, missing,
  incomplete, or wrong-commit contexts are not green.
- Treat `reviewDecision`, unresolved required threads, `mergeable: null`, and
  closingIssuesReferences as provider-native facts, not inferred booleans.

## Publish and act

- Submit a review with `commit_id=headRefOid`; direct merge uses `sha`.
- Ready/draft changes lack an atomic commit guard: sandwich the mutation between
  snapshots and reject any head movement. Use GraphQL `expectedHeadOid` where
  the native mutation exposes it.
- Distinguish direct merge, auto-merge, and merge queue. A queued change validates
  the separate merge-group commit and never reports queued as merged.
- If a requested mutation has no native binding or safe snapshot sandwich,
  return `sha-bound-action-unsupported`.

## Post-merge

Verify the provider-reported result commit for merge, squash, rebase, or indirect
merge; its CI; source-branch cleanup; and linked issue state. Closing keywords
only act when the pull request targets the default branch, and repository
auto-close may be disabled, so `closingIssuesReferences` is a preview rather
than proof of closure.
