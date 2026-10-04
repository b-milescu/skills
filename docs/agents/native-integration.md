# b-milescu/skills native integration

Project-owned integration selected by `provider.reference` in
[the project profile](dev-workflows.md#project-profile-hooks). These are this
repository's facts, not reusable target defaults. Read this document from the
verified target clone.

## Scope and transport

Code, pull requests, work items and advisory CI use the public GitHub repository
<https://github.com/b-milescu/skills> (`b-milescu/skills`), default branch `main`.
Named `origin` fetch and push must both name it (HTTPS or
`git@github.com:b-milescu/skills.git`); resolve fork or alternate-remote intent
explicitly rather than selecting the first remote. Project agents declare no `tools`
and inherit the parent session's tools, so authentication is supplied by the parent's
mounted `github` MCP connection and, for the documented gaps below, the logged-in
`gh` CLI; never inspect or print credential stores or tokens. Every MCP call names
`owner="b-milescu"` and `repo="skills"`; that explicit pair is the destination
binding. Opaque records map to repository-scoped issue/PR numbers, commit SHA,
workflow run/job IDs and comment/review IDs **after** native binding:

| Record | Native form |
| --- | --- |
| Issue locator | `https://github.com/b-milescu/skills/issues/<n>` |
| Change-request locator | `https://github.com/b-milescu/skills/pull/<n>` |
| Durable note id | `issuecomment-<id>` (comment on a PR or issue) or `pullrequestreview-<id>` (PR review) |
| Report locator | `review-report:b-milescu/skills#<pr>:<round>`, chosen before publication |

Use mounted tools documented under `xd://mcp__github_<operation>` (OMP) or
`mcp__github__<operation>` (Claude). Read the current tool schema before use. MCP
first. `gh` fallback only for a documented unavailable-tool, pagination or merge
robustness gap, after all non-transport guards. The documented gaps, which no mounted
MCP tool covers, are repository metadata, closing-reference, merge-state and
merge-commit fields (`gh pr view --json`), source-branch deletion,
branch containment (`compare`), merge-commit parents, `--paginate` completeness and
byte-exact body readback. Run exact command help first and verify flags; cache help
only in this run/context and invalidate on CLI version, command or repository change.
Name the repository on every `gh` command (`-R b-milescu/skills`, a positional
`b-milescu/skills` or a `repos/b-milescu/skills/...` path), never CLI inference from the
working directory. No fallback for stale head, binding, identity, authority, unsafe
text, missing receipt or failed post-read. Native post-read remains mandatory;
unavailable readback means unverified, not success. The sections below follow forge's
operations: preflight, snapshot, publish, act (ready, approval and finish) and
post_merge_snapshot. All five need only this one GitHub repository.

## Preflight and complete reads

1. Compare intended repository against named local remotes and fresh
   `gh repo view b-milescu/skills --json nameWithOwner,url,defaultBranchRef`; verify
   host, name, URL and `main`, not an ID alone. `get_me()` and `gh api user --jq .login`
   must name the same login whenever both transports are used.
2. `get_me()` captures caller identity (login and numeric ID) at entry; retain
   immutable identity and re-read immediately before each write.
3. `issue_read(method="get")` and every page of `issue_read(method="get_comments")`
   read the full work item before pickup. Verify open state and assignees and re-read
   before authoring/launch. Claim/release convention is in [tracker policy](issue-tracker.md#claiming-convention).
4. Lists (`list_issues`, `search_issues`, `list_pull_requests`, `list_label`,
   `actions_list`, comment/review/file/commit pages) are discovery; the ready queue is
   `list_issues(state="OPEN", labels=[<live triage label>])`. Follow `after`/
   `pageInfo.endCursor` (cursor lists) or `page` until a page returns fewer than
   `perPage` items (maximum 100). There is no `pagination.complete` flag, so record the
   terminating page and preserve partiality on caps. `gh api --paginate --slurp` is the
   pagination-robustness fallback. Prefer direct single-record reads for decisions. A
   body cut short by client output limits is not lossless content: recover it with
   `gh api` to a file.
5. PR state, source, target and head come from a fresh `pull_request_read(method="get")`
   or the body-free `gh pr view <n> -R b-milescu/skills --json number,state,isDraft,headRefName,headRefOid,baseRefName,mergeStateStatus,closingIssuesReferences,author`,
   which also supplies the closing-reference and merge-state fields. Review
   needs complete `get_files` (GitHub lists at most 3000 files and omits `patch` for
   binary or oversized ones; a missing `patch` on anything but a pure rename, mode
   change or empty file is incomplete evidence), `get_commits` (at most 250),
   `get_review_comments`, `get_reviews` and `get_comments` pages; truncation is not a
   complete diff.

## Snapshot and receipt evidence

No single read returns handoff evidence. Compose the snapshot from fresh
`pull_request_read` calls: `get` (author login and ID, state, draft, head SHA,
description carrying the Review Packet and Reviewer Lift), `get_files`, `get_reviews`
(Review Reports: reviewer, `commit_id`, body), `get_comments` (Gate Receipts and action
notes: author, body) and `get_check_runs`. Extract Lift, report and receipt claims
locally from those read-back bodies. Verify the current head SHA, each artifact's author
(`user.login`, never a commit author) and that it belongs to this PR; the four
head/author bindings stay claims until then. Extraction alone is not local receipt
validity or execution proof.

To materialize the reviewed commit for local checks, fetch `refs/pull/<n>/head` from the
verified `origin`, require `FETCH_HEAD` to equal the reviewed SHA and add the detached
worktree at that SHA; never an arbitrary `git pull`.

Advisory CI is workflow `check`, job `check` (`.github/workflows/check.yml`). Read it
with `pull_request_read(get_check_runs)`, or with `actions_list(list_workflow_runs)`
(`resource_id="check.yml"`, `workflow_runs_filter` branch/event), `actions_get(get_workflow_run)`
(`head_sha`, `status`, `conclusion`), `actions_list(list_workflow_jobs)` and
`get_job_logs`; `gh run list --workflow check.yml --commit <sha> -R b-milescu/skills` is
the SHA-filtered fallback. Attribute a status only to a run whose `head_sha` equals the
candidate (a `pull_request` run tests GitHub's merge of the head into `main` but reports
the PR head) or, after merge, to the `push` run on `main` whose `head_sha` is the merge
commit. Record the Lift `CI pipeline` cell as
`evidence=<run URL>; status=<conclusion or status>; commit=<head_sha>`. Failed/missing/
pending CI does not affect eligibility, though native protection can refuse writes. A
watcher (`gh run watch`, `gh pr checks --watch`) is advisory progress only, not a local
gate; its one use is the [bounded wait for a held merge](#wait-for-required-checks),
where it only ends the wait.

Run the gate helper (`../../start-build/scripts/validate-gate-receipt.mjs`) by its
resolved absolute path; `<start-build-dir>` below stands for that `start-build`
directory. Follow the
[canonical owner/mode contract](../../start-build/reference/parent-owned-gate.md),
selecting the recipe from the actual `Gate owner`:

- **Parent:** validate the receipt and current candidate Lift before publication:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner parent --mode pre-post --receipt <receipt> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-command <command>
  ```

  No future `--gate-receipt-locator` or `--gate-policy-ref` flags are allowed.
  After publication/readback, validate the same receipt and current Lift against
  the sole labelled opaque `Gate Receipt` pointer and policy:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner parent --mode post-note --receipt <receipt> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-receipt-locator <sole opaque pointer> --gate-command <command> --gate-policy-ref <policy>
  ```

- **Builder:** validate only the existing restricted builder receipt shape:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner builder --mode pre-post --receipt <receipt> --reviewed-commit <commit> --gate-command <command>
  ```

  Builder `post-note` and parent-only binding flags, including `--review-packet`,
  remain refused. Verify `present_anchor` (the read-back comment body has the
  standalone `gate_receipt:` anchor) and `receipt_commit_eq_head` (its
  `checkout_commit` equals the fresh PR head) independently; parent-only post-note
  validation is not builder proof.

Receipt-independent `--mode lift-only --review-packet <packet>` checks required
nonempty rows, unique markers and duplicate rows in either owner context. It is
presence-only: it validates neither row values nor authority, execution or native
identity, and replaces neither receipt validation nor native verification.

GitHub has no native receipt extractor, so the read-back comment body is the
extraction source and the local validator parses that same text. Separately verify
exact `checkout_commit`, `command` and `result` as read back, candidate binding and
artifact author/custody/scope (comment `user.login` equals the verified identity, on
this PR). Actual exact-candidate `bun run check` execution and original-log custody
follow [Check Gate](check-gate.md); readable custody alone is not execution proof.
[Authored-source publication readback](#publish-one-artifact) is another required
proof. Local validity, read-back extraction or a body digest substitutes for none of
these proofs.

## Publish one artifact

Run common no-echo text validation (`../../forge/scripts/validate-text.mjs`, by its
resolved absolute path) before any write; GitHub adds no server-side body validation,
so that check is the only text guard. Preserve authored UTF-8 source in a run file that
ends without a trailing LF, so
newline handling cannot cause a mismatch. GitHub bodies are capped at 65,536
characters; a larger artifact is a transport blocker, never truncated or split.
Readback must equal the source byte for byte: no GitHub normalization is documented for
this repository, so none is tolerated. Recover the exact body with a native GET and
compare it to the source without printing it:

```text
gh api repos/b-milescu/skills/<resource> --template '{{.body}}' > <run-dir>/readback.md
cmp <run-dir>/readback.md <run-dir>/source.md
```

`<resource>` is `issues/comments/<id>` (comment), `pulls/<n>/reviews/<id>` (review),
`pulls/<n>` (PR description) or `issues/<n>` (issue). MCP reads of the same record serve
discovery and metadata, not byte comparison; a `sha256` of the readback is only the same
comparison, never a substitute for the source.

- Draft: push the source, which must be ahead of `main` (GitHub refuses a PR without a
  commit difference), then `create_pull_request` once with `head=<source_branch>`,
  `base="main"`, title, body and `draft=true`. The description contains plain
  `Closes #<issue_number>` outside code spans. Re-read PR state/draft/head/base and the
  complete description.
- Description: `update_pull_request` once with `pullNumber` and only `body`, so draft
  state, title and base stay untouched; native metadata and complete description
  readback must preserve Draft/ready state and candidate.
- Review Report: `pull_request_review_write` once with `method="create"`,
  `event="COMMENT"`, the report as `body` and `commitID=<reviewed SHA>`. `event` is
  always set, because an event-less call leaves an unpublished pending review. Retain
  the review ID (`pullrequestreview-<id>`) and read the exact review back
  (`get_reviews`, then the byte comparison). A Review Report is a PR review, never a
  comment on the linked issue.
- Gate Receipt, Review Packet delta or action note: `add_issue_comment` once with the PR
  number as `issue_number`; retain the returned comment ID (`issuecomment-<id>`) and read
  it back. A comment has no title, so its first heading line is the note title.
  Published artifacts are never repaired with `update_issue_comment`.
- Issue note: `add_issue_comment` once with the issue number, then exact comment
  readback.
- Issue: `issue_write` with `method="create"`, title, body, labels and assignees, after
  `get_me()` verifies identity and `get_label` verifies every label name exists. Local
  numbers alone never verify scope.
- Assignee, labels, body: `issue_write` with `method="update"`, `issue_number` and only the
  scoped field. Assignees and labels **replace** the whole set: read the live set,
  compute the complete final set (non-overlapping adds/removes), send it whole and
  re-read the final state. A body update re-reads and byte-compares like any published
  artifact. Setup never mutates live labels.

Classify creation as verified-created, not-created, created-unverified or unknown.
Known ID uses GET-only recovery. Unknown uses bounded native reconciliation (list the
PR's comments/reviews or the issues by the verified author since the pre-write instant),
never repeat the write; ambiguous/absent matches require human decision. Do not
silently fix lost bodies or mismatched submitted fields with another mutation.

## Ready, approval and finish

Run [common guard](../../forge/reference/common-guard.md) for exactly one action.
Require candidate/Lift and exact-candidate Gate Receipt before ready/review and
independent passing Review Report before finish. Verify authority source, caller
role/context and immediately-before-write identity. Same account may be an independent
session; a builder cannot finish its own change. No GitHub tool combines these checks:
immediately before the one mutation the actor reads `get_me()`, `pull_request_read(get)`
(open, not draft, base `main`, recorded source branch, `head.sha` equal to the reviewed
SHA, the Gate Receipt `checkout_commit` and the Review Report `commit_id`,
`mergeable_state` not `dirty`) and the allocated issue, then reads back.

- Ready: `update_pull_request` with `draft=false` or `gh pr ready <n> -R b-milescu/skills`
  after fresh head and allocated open-item/source/closure checks. Neither takes an
  expected head; re-read draft false, unchanged head and source-equal description. The
  pre/post sandwich is observational, not an atomic expected-head guarantee.
- Approval: unavailable. GitHub refuses `APPROVE` and `REQUEST_CHANGES` from a PR's
  author and every role here is the one GitHub account, so no native approval exists
  and `reviewDecision` is never an oracle; `main` protection requires none. The passing
  Review Report, a `COMMENT` review bound to the reviewed commit, is the review gate
  and carries the verdict in its body; `REQUEST_CHANGES` would need a reviewer account
  other than the PR author. Record Approval action `not-approved` (parent-managed) or
  `blocked: native approval unavailable` with Action blocker `permission-failure`; a
  grant of `approval-only` is denied the same way.
- Direct merge: `merge_pull_request` with `merge_method="merge"` and
  `expectedHeadSha=<reviewed>`, never omitted, under a `reviewer may merge` grant or
  the [project default](dev-workflows.md#finish-authority-default); CI never supplies
  the authority. Required check `check` holds the merge until it passes on the
  reviewed head: GitHub refuses the merge while `check` is pending or failed. Report
  that refusal, never bypass it, and when pending `check` is the only hold
  [wait it out](#wait-for-required-checks) and re-run the finish. Where the finish
  also removes the source branch, use the `gh` form below (the MCP merge has no
  branch delete); `-R` keeps gh from touching local branches.
- Queue: unsupported. `--match-head-commit` binds the head only when GitHub accepts an
  auto-merge request, and GitHub documents cancelling a queued request only for a push
  by someone without write access or a base-branch change, so a later writer push would
  still merge once requirements pass. That is no exact-head guarantee: refuse queueing
  with `sha-bound-action-unsupported` and never issue `--auto` or unbound queueing. A
  `queue auto-merge` grant never authorizes the direct merge above (only
  `reviewer may merge` or the project default does); with no grant at all the blocker
  is `missing-authority`.

```text
gh pr merge <n> -R b-milescu/skills --merge --match-head-commit <reviewed> --delete-branch
```

Native refusals are reported, never bypassed: no `--admin`, ruleset or protection edit,
or direct push to `main`. `main` protection does not enforce admins, so an unrefused
call proves nothing about eligibility; the guard above does. Handoff tokens: a moved
head (REST 409 or GitHub's "Head branch was modified" refusal) is `changed-head-sha`;
`mergeable_state` `dirty` is `merge-conflict`; an action GitHub forbids this account is
`permission-failure`; a missing exact-head binding (any queue request) is
`sha-bound-action-unsupported`; any other hold (required check `check` pending or
failed, draft) is `other` with its one-line reason.

Before finish re-read the recorded allocated **open** issue and exact PR/source/item
relationship, not merely an item inferred from branch text. The plain
`Closes #<issue_number>` in the PR description validates intended syntax; native
`closingIssuesReferences` (`gh pr view <n> -R b-milescu/skills --json closingIssuesReferences`)
and the issue's `closed_by_pull_requests` (`issue_read(get)`) check unintended closures,
and the PR's commit messages and any merge `commit_message` must carry no other closing
keyword because GitHub honours those on merge to `main`; observed post-merge issue state
is the third oracle. Keep these distinct.

### Wait for required checks

Required check `check` (workflow `check`) is `main`'s native merge protection: it can
hold the direct merge, never authorize one, and a pass changes no verdict, review,
approval or authority. When pending `check` is the only hold, whether read before the
call or reported by GitHub's refusal, end the wait with one watcher on the reviewed
head, run under the caller's wait budget as its timeout, then re-run the whole guarded
finish above (fresh `get_me()` and `pull_request_read(get)` reads, the same
`expectedHeadSha`); the earlier refusal is never reused:

```text
gh pr checks <n> -R b-milescu/skills --required --watch
```

`--required` limits the watch to required checks and `--watch` returns when they
finish. MCP-only sessions instead read `pull_request_read(get_check_runs)` at the
[wait cadence](../../start-build/reference/parent-orchestrator.md#wait-cadence) floor
until `check` reports completed. Either way the watcher only ends the wait: it is
advisory, never a local gate, and the re-run guard decides (a push during the wait
moves the head and fails it as `changed-head-sha`). A failed `check`, or a wait that
outlasts the caller's budget, leaves the PR unmerged and blocked with GitHub's
outcome as `other` and its one-line reason, never bypassed.

## Read-only post-merge and cleanup

No GitHub tool returns a post-merge snapshot; compose it from read-only calls.

- PR: `pull_request_read(get)` reports `merged` true, state closed and base `main`; the
  merge commit is `mergeCommit.oid` from
  `gh pr view <n> -R b-milescu/skills --json state,mergeCommit,mergedAt`.
- Reviewed commit: the merge commit's parents from `get_commit(sha=<merge commit>)`, or
  `gh api repos/b-milescu/skills/commits/<merge commit> --jq '[.parents[].sha]'` when the
  MCP result omits them. Merge method `merge` makes the second parent the merged head,
  and it must equal the reviewed SHA. Any other head is a `changed-head-sha` evidence
  gap, reported and never repaired.
- Containment: `gh api repos/b-milescu/skills/compare/<reviewed_sha>...main --jq .status`
  is `ahead` or `identical`; `list_commits(sha="main")` pages cross-check recent merges.
- Linked issue: `issue_read(get)` shows closed. An open issue becomes
  `issue_closure_pending`, never a verifier force-close.
- Result-commit CI: the `push` run of workflow `check` on `main` whose `head_sha` is the
  merge commit, observed independently and advisory.
- Source ref: `gh api repos/b-milescu/skills/git/ref/heads/<source_branch>` returning 404
  means removed; a present branch is reported, not deleted.

Cleanup requires explicit parent authority, session-owned source/worktree, clean state
and proven containment; retain dirty/foreign/unknown/unmerged/unverified worktrees. The
repository deletes merged source branches (verified by the ref read, not assumed). A
branch still present after proven containment is deleted only by a separate guarded
authorized mutation, never by a verifier read:

```text
gh api -X DELETE repos/b-milescu/skills/git/refs/heads/<source_branch>
```
