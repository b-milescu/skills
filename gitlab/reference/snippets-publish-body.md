# GitLab snippets: publish and body

Body-bearing publication snippets: Draft creation, description refresh, the ready transition, notes, and label reconcile. Every body passes the safe-text content-byte guard before mutation.

Entry procedure, transport order, help-first rule, snippet index, and the Mutation Guard pointer stay in [`SKILL.md`](skill://gitlab/SKILL.md). Machine source of truth for snippet names and contracts: `skill://gitlab/reference/snippet-metadata.json`, mirrored by [`snippet-transports.md`](snippet-transports.md). Grouping rationale: [ADR-0002](../../docs/adr/0002-phase-grouped-gitlab-snippet-disclosure.md).

## Snippet: draft-mr-create

Open the early Draft MR only after the source branch exists remotely. MCP primary: validate the Review Packet with `validate_gitlab_text`, then call `create_merge_request(draft=true, source_branch, target_branch, title, description)`. The description must include plain `Closes #<iid>`.

```text

validate_gitlab_text(role="review_packet", content=review_packet)
create_merge_request(project_path, source_branch, target_branch, title, description=review_packet, draft=true)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft=true, source/target/head
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify review_packet byte-for-byte
```

## Snippet: mr-description-update

Refresh the MR description / Reviewer Lift without changing draft/ready state. MCP primary: `safe_update_merge_request_description` validates content bytes and updates the bound MR description. Do not combine with ready-marking.

```text

safe_update_merge_request_description(project_path, mr_iid, description=review_packet)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft state unchanged and head SHA still expected/reviewed SHA when one is in force
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify review_packet byte-for-byte

```

## Snippet: draft-mr-mark-ready

Use only after the local gate has passed (or N/A is documented) and the MR description and Reviewer Lift name the current head SHA.

```text

mark_merge_request_ready(project_path, mr_iid, expected_sha)
get_merge_request(project_path, mr_iid, include_description:false) -> verify draft=false and head SHA still equals reviewed SHA
get_merge_request_description(project_path, mr_iid, description_max_bytes, description_offset_bytes) -> recover and verify the existing description byte-for-byte

```

## Snippet: mr-note-create

Post MR comments only. MCP primary: `safe_create_merge_request_note` validates body bytes, posts one top-level plain non-resolvable MR note on the bound MR, then MR notes/discussions are re-read. Use this for Review Reports and status comments; never use issue-note tools for Review Reports.

```text

safe_create_merge_request_note(project=project_path, merge_request_iid=mr_iid, body=report_body)
merge_request_notes_or_discussions(project_path, mr_iid) -> verify created note exists; for Review Reports, body matches source without printing body

```

Verify source equality from exact-note content or lossless bounded recovery: the
canonical-body digest and `verify_merge_request_note_digest` prove stored-body
equality, not equality to the authored report.

## Snippet: issue-note-create

Post issue comments only. MCP primary: `safe_create_issue_note` validates body bytes, posts one issue note on the bound issue, then issue notes are re-read. Do not use this for Review Reports or MR action reports.

```text

safe_create_issue_note(project_path, issue_iid, body=comment_body)
issue_notes(project_path, issue_iid) -> verify created note exists without printing body

```

## Snippet: label-reconcile

Use MCP `update_issue` label add/remove semantics, then `get_issue(include_description:false)`. Compute add/remove sets first; reject add/remove overlap and final state/category label conflicts before mutation.

```text

update_issue(project_path, issue_iid, add_labels, remove_labels)
get_issue(project_path, issue_iid, include_description:false) -> verify final labels match requested reconcile result

```
