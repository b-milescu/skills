# Bounded metadata and body reads

Guard-grade MR state/SHA reads default to
`get_merge_request_workflow_snapshot`. Use
`get_merge_request(include_description:false)` only when a required metadata
field is absent from the snapshot. Do not couple a description read to a
Mutation Guard or SHA guard.

Issue state, label, or assignment checks use
`get_issue(include_description:false)`. Use `get_issue` or
`get_merge_request` with `description_grep` when only the Closes trailer
or the Reviewer Lift block is needed. Full-body reads stay prescribed
when the flow consumes the whole body.

Request bodies separately through the dedicated MCP readers:

- MR and issue descriptions: `get_merge_request_description` and
  `get_issue_description`. Start with focused `description_grep` when a known
  line or section is sufficient; otherwise use a bounded
  `description_max_bytes`. Follow `descriptionTruncated`,
  `descriptionBytesReturned`, `descriptionOffsetBytes`, and
  `descriptionTotalBytes`; advance `description_offset_bytes` by the returned
  byte count until recovery is complete. Request an unbounded/full description
  only when the whole body is genuinely required.
- Individual MR and issue notes: `get_merge_request_note` and `get_issue_note`.
  Use `body_grep`, `body_max_bytes`, and `body_offset_bytes`, following the
  corresponding `bodyTruncated`, `bodyBytesReturned`, `bodyOffsetBytes`, and
  `bodyTotalBytes` metadata.
  When reading a Gate Receipt or Review Report for one field, pass `body_grep`
  or `body_max_bytes`.

If a bounded response is still elided, retry with a smaller
`description_max_bytes` or `body_max_bytes`, then recover losslessly with
`description_offset_bytes` or `body_offset_bytes`. A help-first `glab api`
body read is a guarded last resort only when the relevant dedicated MCP reader
is unavailable or remains elided after that smaller/chunked attempt.
`glab mr view` metadata projection is likewise last-resort fallback only when
the snapshot and any field-required body-free `get_merge_request` read are
unavailable. Before either fallback, apply the
[GitLab Mutation Guard](mutation-guard.md); advisory CI state never changes
fallback eligibility.

## Schema-first MCP arguments

Before the first call of a mounted MCP tool in a run, verify its required
arguments against the mounted schema. Never take an argument name from memory,
from another tool, or from prose. A rejected call echoes the schema without a
network round trip, so verifying beats retrying; `page` below is one instance.

## Selected list traversal

Use cursor-first traversal for exposed `list_*` tools. On an incomplete result,
resume with `pagination.nextCursor`; omitted filters and `limit` inherit the
selected traversal, while conflicting explicit values are rejected. Follow the
current tool schema rather than assuming every list supports `page`.

Exhaust the selected traversal to `pagination.complete:true` only when the
decision requires completeness. Otherwise retain an explicitly partial candidate
set. Completeness is not a snapshot guarantee: changing server state can affect
later reads. Where `page` is supported, it selects a native page suffix, not the
earlier pages or the entire project, and cannot be combined with `cursor`.

An incomplete first page does not authorize fallback. Use `mcp_pagination_gap`
only for actual inability to complete or recover a required traversal after
native cursor recovery; then apply existing help-first guarded fallback.
Re-read actionable issues/MRs by IID before mutation regardless of traversal
completeness.
