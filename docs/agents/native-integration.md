# agents/skills native integration

Project-owned integration selected by `provider.reference` in
[the project profile](dev-workflows.md#project-profile-hooks). These are this
repository's facts, not reusable target defaults. Installed skill `docs/` aliases
point at repository-owned sources; their native content is exposure, not invoked
foreign-project configuration. Read this document from the verified target clone.

## Scope and transport

Code, merge requests, work items and advisory CI use GitLab instance
<https://gitlab.example.com>, canonical repository `agents/skills`, project 16,
default branch `main`. Named `origin` fetch/push intent must agree; resolve fork or
alternate-remote intent explicitly rather than selecting the first remote.
Authentication is supplied by the mounted `gitlab-mcp` connection; never inspect
or print credential stores. Opaque records map to project-scoped issue/MR IIDs,
commit SHA, pipeline/job and note/discussion locators **after** native binding.

Use mounted tools documented under `xd://mcp__gitlab_mcp_<operation>` (OMP) or
`mcp__gitlab-mcp__<operation>` (Claude). Read the current tool schema before use.
MCP first. `glab` fallback only for a documented unavailable-tool, pagination or
merge robustness gap, after all non-transport guards. Run exact command help
first and verify flags; cache help only in this run/context and invalidate on CLI
version, command or repository change. No fallback for stale head, binding,
identity, authority, unsafe text, missing receipt or failed post-read. Explicit
repository selection is required whenever CLI inference is ambiguous. Native
post-read remains mandatory; unavailable readback means unverified, not success.

## Preflight and complete reads

1. Compare intended repository against named local remotes and fresh
   `get_project(project="agents/skills")`; verify path, web URL and main, not ID
   alone. Bind instance/project together.
2. `get_current_user()` captures caller identity in this instance at entry;
   retain immutable identity and re-read immediately before each write.
3. `get_issue(project, issue_iid)` and `get_issue_discussions` read the full work
   item and every discussion before pickup. Verify opened/assignment and re-read
   before authoring/launch. Claim/release convention is in [tracker policy](issue-tracker.md#claiming-convention).
4. Lists (`list_issues`, `list_merge_requests`, `list_labels`, `list_pipelines`,
   `get_pipeline_jobs`, notes/discussions) are discovery. Follow `nextCursor` until
   `pagination.complete`; preserve partiality on caps. Prefer direct single-record
   reads for decisions. Recover bounded description/note bytes using dedicated
   `get_issue_description`, `get_merge_request_description`, `get_merge_request_note`
   and documented offset fields until lossless complete content is available.
5. `get_merge_request_workflow_snapshot` supplies body-free state/source/target/head;
   use `get_merge_request` for missing metadata. `get_merge_request_changes` and all
   discussions/reviews must be complete for review; truncation is not a complete diff.

## Snapshot and receipt evidence

`get_merge_request_handoff_evidence` supplies workflow snapshot, author, changed
paths, approvals and Lift/report/receipt claims. Verify its current SHA and native
artifact author/custody/scope; extraction alone is not local receipt validity or
execution proof. `get_pipeline` or `list_pipelines(sha=<candidate>)` and jobs provide
advisory CI; status is attributable only to that SHA or proven integration commit.
Failed/missing/pending CI does not affect eligibility, though native protection
can refuse writes. `watch_pipeline` is advisory progress only, not a local gate.

Resolve installed gate helper to its actual filesystem path, then separately:
(1) locally validate receipt and candidate packet; (2) read native handoff evidence
and verify exact extracted checkout_commit/command/result and artifact binding;
(3) post-note validate the same receipt, sole opaque pointer and current Lift.
The local gate owner, execution log and exact-candidate `npm run check` policy stay
in [Check Gate](check-gate.md); no extractor/digest substitutes for those proofs.

## Publish one artifact

Run common no-echo text validation from the installed forge directory before native
safe-write validation. Preserve authored UTF-8 source in a run file. GitLab strips
exactly **one trailing LF** from note/description bodies; compare readback with
source under only that normalization. `verify_merge_request_note_digest` describes
stored-body equality, not authored-source equality. Recover the actual description
or exact note with native GET and compare bytes to the source without printing it.

- Draft: push the source; `create_merge_request(project, source_branch,
  target_branch, title, description, draft=true)` once. Description contains plain
  `Closes #<issue_iid>`. Re-read MR state/source/target/head and complete description.
- Description: `safe_update_merge_request_description` once; native metadata and
  complete description readback must preserve Draft/ready state and candidate.
- MR report/receipt/action note: `safe_create_merge_request_note` once; retain
  returned note ID and use `get_merge_request_note` for exact source readback. A
  Review Report is an MR note, never an issue note.
- Issue note: `safe_create_issue_note` once then exact issue-note GET readback.
- Issue: `create_issue` with freshly verified `expected_project_id`,
  `expected_user_id`, exact existing label bindings and intended publication fields.
  Mounted URL-free schema is required; old `expected_api_url` schema blocks before
  POST. Bound connection owns destination; local IDs alone do not verify instance.
- Assignee/labels: `update_issue` scoped fields; precompute non-overlapping add/remove
  sets from exact live names and re-read final state. Setup never mutates live labels.

Classify creation as verified-created, not-created, created-unverified or unknown.
Known ID uses GET-only recovery. Unknown uses bounded native reconciliation, never
repeat POST; ambiguous/absent matches require human decision. Do not silently fix
lost bodies or mismatched submitted fields with another mutation.

## Ready, approval and finish

Run [common guard](../../forge/reference/common-guard.md) for exactly one action.
Require candidate/Lift and exact-candidate Gate Receipt before ready/review and
independent passing Review Report before approval/finish. Verify authority source,
caller role/context and immediately-before-write identity. Same account may be an
independent session; a builder cannot approve or finish its own change.

- Ready: `mark_merge_request_ready(project, merge_request_iid, expected_sha)` after
  fresh head and allocated open-item/source/closure checks. Re-read Draft false,
  unchanged head and source-equal description. The quick-action pre/post sandwich
  is observational, not an atomic expected-head guarantee.
- Approval: `approve_merge_request(..., sha=<reviewed>, confirm=true)`; re-read
  `get_merge_request_approvals`. Approval alone grants no finish authority.
- Direct merge: `merge_merge_request(..., sha=<reviewed>, confirm=true)`.
- Queue: `merge_merge_request(project, merge_request_iid, sha=<reviewed>,
  auto_merge=true, should_remove_source_branch=true, confirm=true)` or the
  authority-aware finish action below. Acceptance is queued, not merged.
  Documented MCP robustness/CLI 405 gap fallback requires `glab mr merge --help`
  and verified `--auto-merge --sha <reviewed> --remove-source-branch` support,
  followed by native GET. Never issue unbound queueing.
- Authority-aware finish: `finish_merge_request(project, merge_request_iid,
  reviewed_sha, source_branch, target_branch, caller_role="authorized-parent",
  authority="queue auto-merge", authority_source=<verified affirmative source>,
  action="queue-auto-merge", should_remove_source_branch=true)`. Alternatives
  `approval-only`/`direct-merge` require their own matching authority and role.
  Independently verify native MR author and entry/pre-write caller identity;
  those checks are mandatory even when tool schema omits caller/author IDs.
  Native operation must provide the requested exact-head guarantee or refuse.

Before finish re-read the recorded allocated **open** issue and exact MR/source/
item relationship, not merely an item inferred from branch text. Plain
`validate_closes_keyword` validates intended syntax; native `closes_issues`
preview checks unintended closures (code spans may appear in preview); observed
post-merge issue state is the third oracle. Keep these distinct.

## Read-only post-merge and cleanup

`get_post_merge_snapshot(project, merge_request_iid, reviewed_sha)` verifies merged
state, merge/squash/reviewed containment and linked issue/default branch. Queue
acceptance is not merge. Open issue becomes `issue_closure_pending`, never a
verifier force-close. Observe result-commit CI independently. Cleanup requires
explicit parent authority, session-owned source/worktree, clean state and proven
containment; retain dirty/foreign/unknown/unmerged/unverified worktrees. Native
`delete_branch` is a separate guarded authorized mutation, never a verifier read.
