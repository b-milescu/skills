# Finding identities

A review finding is identified by the tuple `(Report locator, Reviewed SHA, Finding ID)`.

- `Report locator` is one stable identifier chosen before the Review Report is posted. Use the eventual durable Review Report artifact URL when it is already known; otherwise use a stable report ID such as `review-report:<project>!<mr-iid>:<round>`. Never publish `pending`, a mutable local path, or a bare MR IID as the locator. The posted comment URL remains separately available as `report_url`.
- `Reviewed SHA` is the exact 40-hex MR head reviewed by that report.
- `Finding ID` remains the short human-readable `MF-N`, `SF-N`, or `C-N` label. A later report may reuse a short ID because the full tuple remains distinct.

Every machine-read cell carries one bare value: the identity table's `Report locator` / `Reviewed SHA` / `Finding ID` cells, and the report's `Reviewed commit` and `Findings summary` cells. Trailing prose inside the value slot is extracted verbatim with the value, so the binding becomes uncomputable. Put commentary in a neighbouring cell or the report body, never after the value.

One report locator maps to exactly one reviewed SHA. Review Reports expose the locator and SHA in their snapshot and list every finding in this marked table; Revision Packets repeat the originating rows they address without renumbering the short IDs:

```markdown
<!-- FINDING-IDENTITY-SCHEMA:BEGIN -->
| Report locator | Reviewed SHA | Finding ID |
|---|---|---|
| `review-report:group/project!123:2` | `1111111111111111111111111111111111111111` | `MF-5` |
<!-- FINDING-IDENTITY-SCHEMA:END -->
```

Reviewer Lift uses the same tuple in its single `Finding bindings` row. Use `none` when no report finding is in flight; otherwise serialize one or more entries as:

```text
report=review-report:group/project!123:2; sha=1111111111111111111111111111111111111111; id=MF-5<br>report=review-report:group/project!123:3; sha=2222222222222222222222222222222222222222; id=SF-1
```

Before publishing a Review Report or Revision Packet, and before a Reviewer Lift participates in a ready transition, run the pure-local validator with every originating report in scope:

```text
node start-review/scripts/validate-finding-bindings.mjs --report <report.md> [--report <report.md> ...] [--packet <revision-packet.md> ...] [--lift <review-packet.md> ...]
```

A Lift whose `Finding bindings` value is `none` can be checked without `--report`. The validator fails publication/ready validation on missing, stale, ambiguous, contradictory, duplicate, or malformed bindings. This identity contract does not change severity, Mutation Guard, Gate Receipt, approval, or merge-authority semantics, and it never requires editing historical reports.
