# Bounded metadata and body reads

Guard-grade MR state/SHA reads default to
`get_merge_request_workflow_snapshot`. Use
`get_merge_request(include_description:false)` only when a required metadata
field is absent from the snapshot. Do not couple a description read to a
Mutation Guard or SHA guard.

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
  `bodyTotalBytes` metadata. An omitted `body_max_bytes` requests the full note,
  so prefer a focused or bounded read when elision or body size is a concern.

If a bounded response is still elided, retry with a smaller
`description_max_bytes` or `body_max_bytes`, then recover losslessly with
`description_offset_bytes` or `body_offset_bytes`. A help-first `glab api`
body read is a guarded last resort only when the relevant dedicated MCP reader
is unavailable or remains elided after that smaller/chunked attempt.
`glab mr view` metadata projection is likewise last-resort fallback only when
the snapshot and any field-required body-free `get_merge_request` read are
unavailable. Before either fallback, preserve project binding and every
applicable reviewed-SHA, exact-candidate Gate Receipt, authority,
caller-identity/context, and content-byte guard; advisory CI state never changes
fallback eligibility.

## Generic shell hygiene

- Paths passed to non-shell binaries must use a namespace that binary can resolve: prefer repo-relative paths, or drive-letter form when the binary requires it, rather than shell-only paths such as `/tmp/...`. When native invocation is unavailable, use the caller-local helper against caller-local paths instead of mixing path namespaces.
- Treat only a comparison tool's exit status as the equality result. A comparison whose absence of output appears to mean equality must not suppress stderr: an unreadable input is an error, not a successful match.
- Treat any `cd` failure as fatal; never continue a validation block in the previous directory.
