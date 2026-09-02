# GitHub Transport

Use only after `preflight` binds GitHub host, owner/repository, and default branch.
Use native REST/GraphQL or `gh`; add no SDK. Bind a pull request to `headRefOid`.

## Snapshot

- Read every paginated file, review, and review thread. Missing pages, GitHub's
  3,000-file REST cap, or incomplete diff/review pagination fails closed.
- Read configured Checks and classic statuses for the exact `headRefOid` when
  available. Classify null, missing, incomplete, or wrong-commit contexts as
  unavailable/unbound advisory observations; no CI state changes eligibility.
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

## Issue publish

Create one issue through native REST/GraphQL or `gh` (no SDK), apply mapped
labels, then re-read the issue and require byte-for-byte body and label match.
Fail closed if this branch cannot name a native create.

## Post-merge

Verify the provider-reported result commit for merge, squash, rebase, or indirect
merge; advisory result-commit CI when bound; source-branch cleanup; and linked
issue state. Closing keywords
only act when the pull request targets the default branch, and repository
auto-close may be disabled, so `closingIssuesReferences` is a preview rather
than proof of closure.
