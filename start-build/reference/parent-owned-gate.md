# Parent-owned Check Gate and Gate Receipt

This is the canonical provider-neutral seam when the child builder hands a Draft
candidate to the parent for the final local Check Gate and ready transition.
The child supplies only the ownership contract and exact candidate commit; it
must not claim local gate PASS/FAIL or Gate Receipt success.

## Ownership contract

```yaml
local_gate_owner: "parent"
builder_gate_status:
  status: "not-run"
  not_run_reason: "parent-owned"
ready_transition_owner: "parent"
```

The parent posts the Gate Receipt and marks ready only after verifying the same
candidate through `forge snapshot` and the target repository Check Gate.

## Gate Receipt schema

Anchor: `gate_receipt.kind=gate-receipt`. Shared fields use opaque strings; the
selected provider validates the change, issue, and durable artifact locators.

```yaml
gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "parent"
  change_id: "opaque-change-id"
  issue_id: "opaque-issue-id"
  checkout_path: "/absolute/path/to/verified/checkout"
  checkout_commit: "1111111111111111111111111111111111111111"
  status_before: "draft"
  status_after: "ready"
  command: "<project Check Gate command>"
  result: "PASS"
  summary: "full project Check Gate completed successfully"
  preflight_checks:
    - name: "clean-status-before"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty"
    - name: "tracked-files-unchanged-after"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty"
  evidence:
    - tier: "tier-1"
      kind: "local-gate"
      source: "opaque artifact locator"
      summary: "command, checkout commit, and result"
  observed_at: "2026-06-01T00:00:00Z"
```

Render once, validate before publication, publish with `forge publish`, and
require provider-native byte-for-byte readback. Then validate the same artifact,
its returned locator, and the current Review Packet before ready:

```text
node skill://start-build/scripts/validate-gate-receipt.mjs --mode pre-post --receipt <receipt> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-command <command>
node skill://start-build/scripts/validate-gate-receipt.mjs --receipt <receipt> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-receipt-locator <opaque provider locator> --gate-command <command> --gate-policy-ref <policy>
```

## Parent verification checklist

1. `forge preflight` binds provider/repository/default branch and the intended
   issue/change request.
2. Draft state, issue closure relationship, source/target, child handoff,
   Reviewer Lift, provider current commit, and remote source all identify the
   same exact candidate.
3. Checkout is clean and at that commit before the full project Check Gate.
4. Gate coverage is `exact-candidate-local`, never `parent-owned`. Provider CI,
   when observed, is advisory and attributed only when bound to the candidate or
   provider-proven integration commit.
5. Tracked files remain unchanged after the gate. If they changed, commit them
   and rerun on the new commit or record an explicit waiver.
6. Gate Receipt contains `result: "PASS"`, exact candidate, command, preflights,
   and evidence; publication readback is byte-for-byte.
7. Reviewer Lift `Acceptance surfaces` all have test/smoke/docs-read/ci/N/A
   evidence, and non-`none` finding bindings validate against their reports.
8. Re-snapshot immediately before one guarded ready mutation. Provider-specific
   CAS or snapshot-sandwich rules live in the selected `/forge` reference.
9. Provider-native post-read confirms ready and unchanged current commit.

The exact candidate plus a passing parent Gate Receipt is sufficient to mark
ready and launch independent review. Provider CI is advisory: pending, failed,
canceled, skipped, missing, stale, wrong-commit, or unavailable status never
changes pass or finish eligibility.

Literal byte-for-byte acceptance strings receive targeted exact-string evidence;
do not expand this into broad ceremony. Such evidence does not substitute for
independent reviewer verification.

## Stale exact-SHA evidence fails closed after a revision push

Any push makes older-commit local gate, CI, review, and Gate Receipt pointers
stale evidence until rebound. Parent-owned mode requires a new exact-commit Gate Receipt
before another ready/review handoff.

## Evidence-ready tokens

- `change-request-description-reviewer-lift-current`
- `candidate-commit-pushed`
- `gate-receipt-exact-commit-pass`
- `ready-transition-post-reread`

Before the receipt, route `phase: parent-gate`, next actor `parent`, next action
`parent-run-gate`, with no extra decision. A Gate Receipt is canonical gate
evidence; later description updates are delta-only.
