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
first. `gh` fallback only for a documented unavailable-tool, pagination, native
artifact resolver/readback or merge robustness gap, after all non-transport guards.
The documented gaps are repository metadata, closing-reference, merge-state and
merge-commit fields (`gh pr view -R github.com/b-milescu/skills --json`), source-branch
deletion, branch containment (`compare`), merge-commit parents, `--paginate`
completeness and byte-exact body readback. A selected create result can supply only
`id`/`url` (observed for this repair's Draft), not a full native record. Do not assume
review-create success text or review pages expose a usable numeric review ID.
Resolve only a missing locator/field/completeness gap as
[Publish one artifact](#publish-one-artifact) directs; a known locator uses direct
GET, not an extra discovery scan on every successful write. These result-shape gaps
are not proof of a defect or of the running MCP server revision.
Run exact command help first and verify flags; cache help
only in this run/context and invalidate on CLI version, command or repository change.
`list_label` takes no pagination arguments. When `labels.length` is not `totalCount`,
recover with the help-verified label read in
[Preflight and complete reads](#preflight-and-complete-reads).
Name the host and repository on every `gh` recipe so `GH_HOST` cannot rebind it.
`gh api` takes `--hostname github.com`. `gh repo view` and `-R` name
`github.com/b-milescu/skills`. API paths stay `repos/b-milescu/skills/...` under that
hostname. Never infer the host from the working directory, and do not write global
`gh` config or the environment to force it. No fallback for stale head, binding,
identity, authority, unsafe
text, missing receipt or failed post-read. Native post-read remains mandatory;
unavailable readback means unverified, not success. The sections below follow forge's
operations: preflight, snapshot, publish, act (ready, approval and finish) and
post_merge_snapshot. Each operation uses only this target's independently
configured GitHub scopes on `b-milescu/skills`. No unrelated tracker, CI host or
other authentication is required, and missing unrelated auth never blocks a
supported operation.

| Operation | Required GitHub scope | Unrelated auth |
| --- | --- | --- |
| `preflight` | The scope being bound: code, change request, work item or advisory CI, all this repository | none |
| `snapshot` | Read-only evidence on this repository | none |
| `publish` | One authorized artifact write on this repository under the native-validation/readback recipe below; enforce any authoritative known bound in its known unit | none |
| `act` | One guarded mutation on this repository | none |
| `post_merge_snapshot` | Read-only merged-state reads on this repository | none |

## Preflight and complete reads

1. Compare intended repository against named local remotes and fresh
   `gh repo view github.com/b-milescu/skills --json nameWithOwner,url,defaultBranchRef`; verify
   host `github.com`, name, URL and `main`, not an ID alone. `get_me()` and
   `gh api --hostname github.com user --jq '{login,id}'` must name the same login
   and the same numeric ID whenever both transports are used.
2. `get_me()` captures caller identity (login and numeric ID) at entry; retain
   immutable identity and re-read immediately before each write.
3. `issue_read(method="get")` and every page of `issue_read(method="get_comments")`
   read the full work item before pickup. Verify open state and assignees and re-read
   before authoring/launch. Claim/release convention is in [tracker policy](issue-tracker.md#claiming-convention).
4. Cursor and page lists (`list_issues`, `search_issues`, `list_pull_requests`,
   `actions_list`, comment/review/file/commit pages) are discovery, never merged-state
   proof. The ready queue is `list_issues(state="OPEN", labels=[<live triage label>])`.
   Follow `after` / `pageInfo.endCursor` (cursor lists) or `page` until a page returns
   fewer than `perPage` items (maximum 100). There is no `pagination.complete` flag, so
   record the terminating page and preserve partiality on caps. `gh api --hostname github.com --paginate --slurp`
   is the pagination-robustness fallback for those cursor and page tools.
   `list_label(owner="b-milescu", repo="skills")` takes only `owner` and `repo`. Do not
   pass `after`, `page`, `perPage` or `pageInfo`. It returns `labels` and `totalCount`.
   Completeness is `labels.length == totalCount` in that single response, a different
   contract from cursor and page termination. The mounted implementation requests
   `labels(first: 100)` and returns `totalCount` with no cursor
   ([labels.go](https://github.com/github/github-mcp-server/blob/main/pkg/github/labels.go)),
   so a longer inventory cannot be completed by calling `list_label` again. When
   `labels.length` is not `totalCount`, do not treat that array as the inventory.
   After this run's exact command help verifies the flags, recover with
   `gh api --hostname github.com 'repos/b-milescu/skills/labels?per_page=100' --paginate --slurp`.
   Aggregate every page. Require the aggregated names and count to equal a fresh
   `list_label` `totalCount`; otherwise the affected label-based action blocks.
   Do not record a setup-time count as the inventory. Prefer direct
   single-record reads for decisions.
5. PR state, source, target and head come from a fresh `pull_request_read(method="get")`
   or the body-free `gh pr view <n> -R github.com/b-milescu/skills --json number,state,isDraft,headRefName,headRefOid,baseRefName,mergeStateStatus,closingIssuesReferences,author`,
   which also supplies the closing-reference and merge-state fields. Review
   needs complete `get_files` (GitHub lists at most 3000 files and omits `patch` for
   binary or oversized ones; a missing `patch` on anything but a pure rename, mode
   change or empty file is incomplete evidence), `get_commits` (at most 250),
   `get_review_comments`, `get_reviews` and `get_comments` pages. A body cut short by
   client output limits is not lossless content: recover it with `gh api --hostname github.com` to a file.
   Unresolved truncation of that body, the diff or the discussion refuses only the
   decision that required the complete read. Lists never prove merged state.

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
`get_job_logs`; `gh run list --workflow check.yml --commit <sha> -R github.com/b-milescu/skills` is
the SHA-filtered fallback. Attribute a status only to a run whose `head_sha` equals the
candidate (a `pull_request` run tests GitHub's merge of the head into `main` but reports
the PR head) or, after merge, to the `push` run on `main` whose `head_sha` is the merge
commit. Record the Lift `CI pipeline` cell as
`evidence=<run URL>; status=<conclusion or status>; commit=<head_sha>`. Failed/missing/
pending CI does not affect eligibility, though native protection can hold or refuse
writes. A watcher (`gh run watch -R github.com/b-milescu/skills`, `gh pr checks -R github.com/b-milescu/skills --watch`) is advisory progress only,
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

The materialization and owner-mode commands below are unchanged. They validate
artifacts, not publication authority or capacity. A native comment write separately
requires [Packet home](#packet-home) and [Publish one artifact](#publish-one-artifact).

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

The packet home remains the PR description: it holds the Review Packet and its
Reviewer Lift in full, not a pointer to a note. Do not move it to a note, truncate
it, split it, or use a hidden fallback.

No supported current ceiling or Unicode counting unit is confirmed for the
packet/description or the other body surfaces below. Unknown is not unlimited.
Do not invent a UTF-8, UTF-16, code-point or character cap, assume a title/global
body limit or probe a ceiling. Enforce any applicable authoritative limit in its
declared unit if later documented.
[Discussion 27190](https://github.com/orgs/community/discussions/27190) is conflicting
historical evidence, not a current bound: a 2020 staff note equated a mediumblob with
65,536 4-byte characters; later comments report both a `maximum is 65536 characters`
API error and larger comments succeeding; current REST documentation does not publish
that figure. Neither those remarks nor a request schema without a bound proves
capacity or grants publication authority.

| Surface | Artifact | Size, unit, evidence | Publication |
| --- | --- | --- | --- |
| PR description | Review Packet and description | undocumented ceiling/unit | one otherwise authorized ordinary native attempt plus original-source verification below |
| Issue body | issue body | undocumented ceiling/unit | same native-validation recipe |
| PR or issue comment | Gate Receipt, action note, issue note | undocumented ceiling/unit | same native-validation recipe |
| PR review body | Review Report | undocumented ceiling/unit | same recipe plus this-run review identity |

This target confirms [Publish one artifact](#publish-one-artifact) as its
native-validation recipe for these undocumented surfaces. The owner-approved
[issue #11 amendment](https://github.com/b-milescu/skills/issues/11) also permits
the ordinary repair artifacts under this recipe before the amended shared policy
lands; that bootstrap is not post-fix consumer evidence. Possible refusal,
unverified artifacts/notifications and manual recovery are accepted, not corrupted
decision inputs. Configuration is not action authority. The description still
holds the complete packet and one Reviewer Lift block; no truncation, splitting,
shortening to evade refusal, note-home migration or hidden transport switch.

## Publish one artifact

Run the common guard for one otherwise authorized native attempt. Undocumented
capacity alone does not refuse that attempt under [Packet home](#packet-home);
known applicable bounds still apply. Retain the complete pre-write source,
destination, fields, immutable actor, head when relevant and pre-write instant.
For a selected creation recipe without a guaranteed usable locator, also retain
the scoped pre-write artifact evidence needed by the reconciliation below.
Native permission never grants action authority.

Run common no-echo text validation before writing: resolve
`scripts/validate-text.mjs` inside the installed `forge` skill (the skill the runtime
loaded, never this checkout's copy, for the same reason as the gate helper above)
and run it by that resolved absolute path. GitHub adds no server-side safe-text
validation, so that check is the text guard, not a capacity check. Submit exactly
the validated authored string. Keep its UTF-8 bytes, actual line endings and any
authored trailing LF unchanged; do not trim or reconstruct source after writing.
No target normalization is confirmed.

Use a complete native GET, not the write response/echo, to bind the record's ID,
URL and repository/change relationship to the selected destination. Require
`user.login` and immutable `user.id` to match the retained authenticated actor;
verify supplied fields and head/commit where applicable. Before extraction require
the native `body` field to be present and a string, never missing/null or coerced.
Recover the full body without printing it and compare against the original:

```text
gh api --hostname github.com repos/b-milescu/skills/<resource> > <run-dir>/native.json
bun -e '
const fs = require("node:fs");
let record;
try {
  record = JSON.parse(new TextDecoder("utf-8", {fatal:true}).decode(fs.readFileSync(process.argv[1])));
} catch {
  console.error("native-readback-invalid");
  process.exit(1);
}
if (typeof record.body !== "string") {
  console.error("native-body-unavailable");
  process.exit(1);
}
fs.writeFileSync(process.argv[2], record.body, "utf8");
' <run-dir>/native.json <run-dir>/readback.md
cmp <run-dir>/readback.md <run-dir>/source.md
```

`<resource>` is `issues/comments/<id>` (comment), `pulls/<n>/reviews/<id>` (review),
`pulls/<n>` (PR description) or `issues/<n>` (issue). Retain the complete native
record, extracted body, metadata binding and comparison outcome separately.
Extraction or a readback-only digest is not submitted-source equality. MCP reads
serve snapshots/metadata, not byte comparison. A mismatch, missing/null body,
refusal, unavailable GET or uncertain outcome stays unverified and blocks
dependent Ready/review/finish; never edit source or submitted fields to force
success.

- Draft: push the source, which must be ahead of `main` (GitHub refuses a PR without a
  commit difference), then `create_pull_request` once with `head=<source_branch>`,
  `base="main"`, title, body and `draft=true`. The description contains plain
  `Closes #<issue_number>` outside code spans. Retain the returned locator and
  resolve it with `pull_request_read(get)` and the exact `pulls/<n>` GET above;
  verify open/Draft, repository/source/base/head, actor, fields, closure relationship
  and full original-source equality before consuming the packet.
- Description: `update_pull_request` once with `pullNumber` and only `body`, so draft
  state, title and base stay untouched; native metadata and complete description
  readback must preserve Draft/ready state and candidate. This is an intentional
  packet refresh, never silent repair of an unverified write.
- Review Report: `pull_request_review_write` once with `method="create"`,
  `event="COMMENT"`, the report as `body` and `commitID=<reviewed SHA>`. Always set
  `event`; an event-less call leaves an unpublished pending review. If the selected
  recipe has no guaranteed review locator, retain complete pre-write review IDs
  and a previously unused canonical report locator before writing. A returned
  numeric review ID goes directly to `pulls/<n>/reviews/<id>` GET; otherwise use
  the one bounded native resolver below. Require same PR, actor, `commit_id`,
  submitted `COMMENTED` state, this-run identity and original-source equality.
  A Review Report is a PR review, never a comment on the linked issue.
- Gate Receipt, Review Packet delta or action note: `add_issue_comment` once with the PR
  number as `issue_number`; retain the returned comment ID (`issuecomment-<id>`) and
  read it back, verifying `issue_url` names this PR before full-byte comparison.
  A comment has no title, so its first heading line is the note title.
  Published artifacts are never repaired with `update_issue_comment`.
- Issue note: `add_issue_comment` once with the issue number; require that issue's
  scoped comment identity and exact original-source readback.
- Issue create: `issue_write` with `method="create"`, title, body, labels and assignees,
  after `get_me()` verifies identity and the complete label inventory in
  [Preflight and complete reads](#preflight-and-complete-reads) contains every label
  name. Local numbers alone never verify scope. Verify original body, title, scoped
  identity, assignees and supplied labels before any dependent transition; apply
  `ready-for-agent` only after that verification, never in the initial create.
- Assignee or labels: supported metadata replacement, not a body publication.
  `issue_write` with `method="update"`, `issue_number` and only the scoped field.
  Assignees and labels **replace** the whole set: read the issue's live set, compute
  the complete final set (non-overlapping adds/removes), send it whole and re-read
  the final state. Before adding a label, that complete inventory must show the
  name. An incomplete inventory blocks the label-based action. Setup never mutates
  live label definitions.
- Issue body update: `issue_write` with `method="update"`, `issue_number` and only
  `body`, then the same native metadata/original-byte comparison.

Classify creation as verified-created, not-created, created-unverified or unknown.
Only explicit native non-creation evidence permits `not-created`; a generic
tool/server error or timeout is not rollback proof. No classification permits
automatic repeat creation or silent body/field repair.

A known-created locator uses GET-only recovery of that exact record. With no
usable locator, make one bounded read-only native reconciliation pass in the
verified repository/change: PRs by the recorded source/base, that issue/PR's
comments or reviews, or issues by the verified author since the pre-write instant.
Use documented MCP pagination when it supplies complete IDs/records; for missing
review IDs/fields or pagination gaps use the help-verified native resolver:
`gh api --hostname github.com 'repos/b-milescu/skills/pulls/<n>/reviews?per_page=100' --paginate --slurp`.
Aggregate all pages within that one pass; a truncated/unavailable list is not a
second pass or proof of absence. Do not run this scan for a successful write whose
usable locator already resolves directly.

Require a unique new artifact with native correlation to this attempt or complete
pre-write ID evidence plus the recorded source/fields and previously unused report
locator where applicable; then GET that exact record and verify all metadata/body
bytes. Author, head, timestamp and even identical body bytes alone cannot identify
this run's artifact. Reject every pre-existing ID, never select the newest/first
matching historical report, and stop on multiple new candidates. Absence,
ambiguity, missing pre-write evidence, incomplete readback or mismatch blocks
dependent transitions and requires a human decision, with the original source and
known locator retained. No recreate, silent repair or transport/home fallback.

## Ready, approval and finish

Run [common guard](../../forge/reference/common-guard.md) for exactly one action.
Require candidate/Lift and exact-candidate Gate Receipt before ready/review and
independent passing Review Report before finish. Verify authority source, caller
role/context and immediately-before-write identity. Same account may be an independent
session; a builder cannot finish its own change. No GitHub tool combines these checks:
immediately before the one mutation the actor reads `get_me()`, `pull_request_read(get)`
and the allocated open issue, then reads back. Common reads are open, base `main`,
recorded source branch, and `head.sha` equal to the reviewed SHA, plus the Gate
Receipt `checkout_commit` and Review Report `commit_id` as relevant to that action,
and `mergeable_state` not `dirty`. Draft state is action-specific: Ready expects
Draft before the mutation and ready after; Finish requires not Draft. Readiness has
no unconditional not-Draft prerequisite. Exact head, receipt binding, and the
allocated open item stay required.

- Ready: `update_pull_request` with `draft=false` or `gh pr ready <n> -R github.com/b-milescu/skills`
  from Draft, after fresh head and allocated open-item/source/closure checks. Neither
  takes an expected head; re-read draft false, unchanged head and source-equal
  description. The pre/post sandwich is observational, not an atomic expected-head
  guarantee.
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
  the authority. The request field alone is not the guarantee. Exact-head rests on the
  documented stale-head rejection.
  [REST merge contract](https://github.com/github/rest-api-description/blob/836ce198db13a6fb194547e53eea99c6ddae495b/descriptions/api.github.com/api.github.com.yaml#L53112-L53240)
  defines REST `sha` as "SHA that pull request head must match to allow merge" and
  returns 409 if `sha` was provided and the pull request head did not match. The
  first-party [github-mcp-server#3182 diff](https://github.com/github/github-mcp-server/pull/3182.diff)
  forwards `expectedHeadSha` to `PullRequestOptions.SHA` and returns that 409 as a
  single-call error with no retry. The mounted schema exposes `expectedHeadSha`;
  exposure is not proof. This reference does not claim those upstream tests were run
  here, and no live probe was run. No setup stale-head probe applies. Do not use
  `gh pr merge`: verified `gh` 2.102.0 help says it may enable auto-merge for a
  branch that requires a merge queue even without `--auto`, contrary to this
  target's no-queue contract. Do not use the asynchronous merge API. Required check
  `check` may hold or refuse the merge: `main` protection enforces admins, so GitHub
  holds it for every account, this repository's sole admin account included, until
  `check` passes on the reviewed head. That is GitHub's outcome, never an eligibility
  decision, and the finisher never reads `check` to decide eligibility. Report the
  hold or refusal, never bypass it, and when pending `check` is the only hold
  [wait it out](#wait-for-required-checks) and re-run the finish. This call does not
  delete the source branch. Server-side delete-on-merge is observed by the post-merge
  ref read. Actor cleanup uses the separately guarded
  [cleanup recipe](#read-only-post-merge-and-cleanup) and its explicit authority.
  If `merge_pull_request` is unavailable, and only after every non-transport guard
  has passed, the pure direct REST fallback below is the documented unavailable-tool
  gap. It does not queue. No fallback after a stale head, an unsupported commit
  binding, an identity, authority, body or receipt guard failure, or a native refusal.
- Queue: unsupported. `--match-head-commit` binds the head only when GitHub accepts an
  auto-merge request, and GitHub documents cancelling a queued request only for a push
  by someone without write access or a base-branch change, so a later writer push would
  still merge once requirements pass. That is no exact-head guarantee: refuse queueing
  with `sha-bound-action-unsupported` and never issue `--auto`, `gh pr merge`, or
  unbound queueing. A `queue auto-merge` grant never authorizes the direct merge
  above or the REST fallback below, even beside the
  standing project default: that default applies only when it is the value quoted in
  the Lift's `Finish authority`, and an explicit grant takes precedence over it. Only
  `reviewer may merge` or the quoted project default authorizes the direct merge; with
  no grant at all the blocker is `missing-authority`. Do not fall back from a
  refused queue request to the direct merge.

```text
gh api --hostname github.com --method PUT repos/b-milescu/skills/pulls/<n>/merge --raw-field merge_method=merge --raw-field sha=<reviewed>
```

Native refusals are reported, never bypassed: no `--admin`, ruleset or protection edit,
or direct push to `main`. `main` protection enforces admins
(`gh api --hostname github.com repos/b-milescu/skills/branches/main/protection --jq .enforce_admins.enabled`
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
`closingIssuesReferences` (`gh pr view <n> -R github.com/b-milescu/skills --json closingIssuesReferences`)
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
gh pr checks <n> -R github.com/b-milescu/skills --required
```

Map the exit status of each poll:

- `0`: not proof (`gh` also exits `0` with a cancelled required check, and `--json`
  exits `0` whatever the buckets). Confirm with
  `gh pr checks <n> -R github.com/b-milescu/skills --required --json name,bucket`: when every
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
Lists never prove merged state; `list_pull_requests` is not this snapshot.

- PR: `pull_request_read(get)` reports `merged` true, state closed and base `main`; the
  merge commit is `mergeCommit.oid` from
  `gh pr view <n> -R github.com/b-milescu/skills --json state,mergeCommit,mergedAt`.
- Reviewed commit: the merge commit's parents from `get_commit(sha=<merge commit>)`, or
  `gh api --hostname github.com repos/b-milescu/skills/commits/<merge commit> --jq '[.parents[].sha]'` when the
  MCP result omits them. Merge method `merge` makes the second parent the merged head,
  and it must equal the reviewed SHA. Any other head is a `changed-head-sha` evidence
  gap, reported and never repaired.
- Containment: `gh api --hostname github.com repos/b-milescu/skills/compare/<reviewed_sha>...main --jq .status`
  is `ahead` or `identical`; `list_commits(sha="main")` pages cross-check recent merges.
- Linked issue: `issue_read(get)` shows closed. An open issue becomes
  `issue_closure_pending`, never a verifier force-close.
- Result-commit CI: the `push` run of workflow `check` on `main` whose `head_sha` is the
  merge commit, observed independently and advisory.
- Source ref: `gh api --hostname github.com repos/b-milescu/skills/git/ref/heads/<source_branch>` returning 404
  means removed; a present branch is reported, not deleted.

Cleanup requires explicit parent authority, session-owned source/worktree, clean state
and proven containment; retain dirty/foreign/unknown/unmerged/unverified worktrees. The
repository deletes merged source branches (verified by the ref read, not assumed). A
branch still present after proven containment is deleted only by a separate guarded
authorized mutation, never by a verifier read:

```text
gh api --hostname github.com -X DELETE repos/b-milescu/skills/git/refs/heads/<source_branch>
```
