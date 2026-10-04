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
pending CI does not affect eligibility, though native protection can hold or refuse
writes. A watcher (`gh run watch`, `gh pr checks --watch`) is advisory progress only,
never a local gate and never the held-merge wait; that wait polls as in
[Wait for required checks](#wait-for-required-checks).

Run the gate helper from the installed `start-build` skill, never from this checkout:
resolve `scripts/validate-gate-receipt.mjs` inside the installed start-build skill (the
skill the runtime loaded; [skill invocation and resource paths](../../agents/README.md#skill-invocation-and-resource-paths)
says where each runtime keeps it) and run it by that resolved absolute path.
`<start-build-dir>` below stands for that installed directory. A PR must not be
validated by its own modified validator, and this checkout's `start-build/` is code a
PR may change. Follow the
[canonical owner/mode contract](../../start-build/reference/parent-owned-gate.md),
using the raw YAML files materialized below for the actual `Gate owner`.

### Materialize the receipt YAML

`--receipt` consumes raw block-style YAML, never a whole Markdown note. Keep
`authored-note.md` (the complete submitted body), `readback-note.md` (the complete
lossless native GET body), and the separately materialized
`authored-receipt.yaml` / `readback-receipt.yaml`. Use this procedure on each
complete body independently:

1. For a Markdown note, inspect all top-level fenced blocks, not just the first
   YAML fence. The supported receipt fence opens with a column-one line exactly
   ` ```yaml ` (without the surrounding spaces) and closes with a column-one line
   exactly ` ``` ` (without the surrounding spaces). Within YAML fences, count
   receipt candidates by a column-one `gate_receipt:` mapping-key line, including
   nonplain forms such as `gate_receipt: &gate_receipt`. An unrelated YAML fence
   without that mapping is not a receipt candidate.
2. Require exactly one receipt candidate in the complete note and a matching
   closing fence. Require its document to start with the standalone plain line
   `gate_receipt:` followed only by its indented block-style child fields; no
   second top-level mapping or receipt anchor. Missing, multiple/ambiguous,
   unterminated or alias-style (`&` / `*`) receipt anchors refuse materialization.
   Do not choose the first match, guess a missing fence or repair a document.
3. Copy the contiguous bytes immediately after the opening fence's line ending
   up to (excluding) the closing fence line into the raw `.yaml` file, preserving
   indentation, scalar spelling and line endings. Do not include the title,
   fence delimiters or evidence bullets, reconstruct fields, trim the document
   or parse/re-dump YAML.
4. A parent receipt may instead be published as the raw block-style document:
   the complete body starts with the standalone plain `gate_receipt:` line and
   contains only its indented fields, with no Markdown wrapper. For that
   explicitly supported parent form, copy the entire body byte for byte as the
   raw input. Refuse duplicate/alias-style anchors or mixed Markdown/YAML;
   builder publication still requires its titled, fenced, evidence-bearing note.

Before publication, safe-text validate the **complete authored body** and run
the owner-specific receipt validation on `authored-receipt.yaml`. After native
GET, require byte equality of `authored-note.md` and `readback-note.md` per
[Publish one artifact](#publish-one-artifact), then independently materialize
`readback-receipt.yaml` and require its byte equality with
`authored-receipt.yaml`. Full-note comparison cannot be replaced by comparison
or a digest of just the extracted YAML. Do not print submitted bodies in failure
diagnostics.

### Owner-mode validation

- **Parent:** validate the authored raw YAML and current candidate Lift before
  publishing the complete body:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner parent --mode pre-post --receipt <authored-receipt.yaml> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-command <command>
  ```

  No future `--gate-receipt-locator` or `--gate-policy-ref` flags are allowed.
  After complete native readback and materialization, validate the read-back raw
  YAML and current Lift against the sole labelled opaque `Gate Receipt` pointer
  and policy:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner parent --mode post-note --receipt <readback-receipt.yaml> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-receipt-locator <sole opaque pointer> --gate-command <command> --gate-policy-ref <policy>
  ```

- **Builder:** validate only the restricted builder receipt shape: authored raw
  YAML before publication, then read-back raw YAML afterward, both in pre-post:

  ```text
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner builder --mode pre-post --receipt <authored-receipt.yaml> --reviewed-commit <commit> --gate-command <command>
  bun <start-build-dir>/scripts/validate-gate-receipt.mjs --owner builder --mode pre-post --receipt <readback-receipt.yaml> --reviewed-commit <commit> --gate-command <command>
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

GitHub has no native receipt extractor. The complete read-back comment body is
the extraction source; the local validator parses the raw YAML materialized from
it, not that whole Markdown body. Separately verify exact `checkout_commit`,
`command` and `result` as read back, binding to the fresh PR head and artifact
author/custody/scope (comment `user.login` and immutable ID match the verified
identity, on this PR). Actual exact-candidate `bun run check` execution and
original-log custody follow [Check Gate](check-gate.md); readable custody alone
is not execution proof. Full authored-body safe-text validation and
[authored-source publication readback](#publish-one-artifact) remain independent
requirements. Materialization, local validity, extraction, SHA equality or a
body digest substitutes for none of those proofs or for authority.

### Parent supported-input smoke

For this documentation/input-seam correction, the parent exercises the procedure
above in throwaway local authored/readback representations with the actual
existing installed helper CLI: parent pre-post then post-note with the current
Lift/locator, and builder pre-post on both raw files. Cover titled/fenced notes
for both owners and the raw parent form; put an unrelated YAML fence before a
valid receipt to prove selection is not first-fence selection. Missing, duplicate,
unterminated and alias-style candidates must refuse materialization before helper
invocation, without field repair. Retain full-body and extracted-byte comparisons
and CLI outcomes, not assertions about documentation strings. Do not repeat the
known whole-Markdown wrong-input command or publish fixtures as real Gate
Receipts. Fixture success is not gate execution evidence: the normal isolated
exact-candidate `bun run check`, durable Gate Receipt and fresh independent final
review still precede an authorized exact-head merge.

## Packet home

The packet home is the PR description: it holds the Review Packet and its Reviewer
Lift in full, not a pointer to a note. Its size limit is 65,536 characters, the
figure GitHub's API names when it refuses a longer PR body
(`body is too long (maximum is 65536 characters)`); GitHub's documentation publishes
no number. A packet over the limit is refused as a transport blocker before
publication, never truncated or split. Publication, byte-exact readback and the
Reviewer Lift marker-block rules apply to the description as published
([Publish one artifact](#publish-one-artifact)).

## Publish one artifact

Run common no-echo text validation before any write: resolve `scripts/validate-text.mjs`
inside the installed `forge` skill (the skill the runtime loaded, never this checkout's
copy, for the same reason as the gate helper above) and run it by that resolved
absolute path. GitHub adds no server-side body validation, so that check is the only
text guard. Preserve authored UTF-8 source in a run file that ends without a trailing
LF, so newline handling cannot cause a mismatch. GitHub bodies are capped at 65,536
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
  the authority. GitHub documents the stale-head rejection that makes this exact-head:
  `expectedHeadSha` is the REST merge `sha` ("SHA that pull request head must match
  to allow merge", 409 when the head differs) and `--match-head-commit` is the same
  binding in `gh` ("Commit SHA that the pull request head must match to allow
  merge"), so no setup stale-head probe applies. Required check `check` may hold or
  refuse the merge: `main`
  protection enforces admins, so GitHub holds it for every account, this repository's
  sole admin account included, until `check` passes on the reviewed head. That is
  GitHub's outcome, never an eligibility decision, and the finisher never reads
  `check` to decide eligibility. Report the hold or refusal, never bypass it, and
  when pending `check` is the only hold [wait it out](#wait-for-required-checks) and
  re-run the finish. Where the finish also removes the source branch, use the `gh`
  form below (the MCP merge has no branch delete); `-R` keeps gh from touching local
  branches.
- Queue: unsupported. `--match-head-commit` binds the head only when GitHub accepts an
  auto-merge request, and GitHub documents cancelling a queued request only for a push
  by someone without write access or a base-branch change, so a later writer push would
  still merge once requirements pass. That is no exact-head guarantee: refuse queueing
  with `sha-bound-action-unsupported` and never issue `--auto` or unbound queueing. A
  `queue auto-merge` grant never authorizes the direct merge above, even beside the
  standing project default: that default applies only when it is the value quoted in
  the Lift's `Finish authority`, and an explicit grant takes precedence over it. Only
  `reviewer may merge` or the quoted project default authorizes the direct merge; with
  no grant at all the blocker is `missing-authority`.

```text
gh pr merge <n> -R b-milescu/skills --merge --match-head-commit <reviewed> --delete-branch
```

Native refusals are reported, never bypassed: no `--admin`, ruleset or protection edit,
or direct push to `main`. `main` protection enforces admins
(`gh api repos/b-milescu/skills/branches/main/protection --jq .enforce_admins.enabled`
is `true`), so GitHub's rules bind this repository's sole admin account too. They check
only that the change arrives by pull request and that `check` passes: GitHub verifies
no review, Gate Receipt or authority, so an unrefused call proves only that those held,
never eligibility; the guard above decides. Handoff tokens: a moved head (REST 409 or
GitHub's "Head branch was modified" refusal) is `changed-head-sha`; `mergeable_state`
`dirty` is `merge-conflict`; an action GitHub forbids this account is
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

Required check `check` (workflow `check`) is `main`'s native merge protection: it may
hold or refuse the direct merge, never authorize one, and a pass changes no verdict,
review, approval or authority. The finisher never reads `check` to decide
eligibility: it makes the guarded merge call, and only when GitHub holds that call
for pending `check` does it wait, within the
[required-check wait budget](../../start-build/reference/parent-orchestrator.md#required-check-wait-budget):
30 minutes from the first hold, because this reference sets no different bound. When
the checks pass, re-run the whole guarded finish above (fresh `get_me()` and
`pull_request_read(get)` reads, the same `expectedHeadSha`); the earlier refusal is
never reused. Poll the reviewed head at each
[wait floor](../../start-build/reference/parent-orchestrator.md#wait-cadence) until the
budget is spent; the finisher tracks the elapsed time itself, so no external timeout
tool is needed:

```text
gh pr checks <n> -R b-milescu/skills --required
```

Map the exit status of each poll:

- `0`: not proof (`gh` also exits `0` with a cancelled required check, and `--json`
  exits `0` whatever the buckets). Confirm with
  `gh pr checks <n> -R b-milescu/skills --required --json name,bucket`: when every
  required `bucket` is `pass` or `skipping`, re-run the guarded finish; a `cancel` or
  `fail` bucket is a failure; any other bucket (`pending`) means poll again at the
  next floor.
- `8`: the checks are still pending. Poll again at the next floor.
- `1` with failing checks listed in the output: a required check failed.
- `1` with none listed (`no checks reported`, `no required checks reported`, a network
  or GraphQL error, no commit found): an unknown read, not a failure. A `check` not
  yet registered on the head (GitHub's `expected` state) is not completion either.
  Poll again at the next floor within the budget.
- A failure, or the budget spent with no confirmed pass: the PR stays unmerged and
  blocked.

MCP-only sessions instead read `pull_request_read(get_check_runs)` at each wait floor,
within the same budget: no `check` run yet, or one queued or in progress, keeps the
wait going; a completed run with conclusion `success`, `skipped` or `neutral` (the
statuses GitHub's required-check rule accepts) re-runs the guarded finish; any other
completed conclusion is a failure. Either way the poll only ends the wait:
it is advisory, never a local gate, and the re-run guard decides (a push during the
wait moves the head and fails it as `changed-head-sha`). A failed `check` or an
elapsed budget leaves the PR unmerged and blocked with GitHub's outcome as `other`
and its one-line reason, never bypassed.

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
