# Parent-owned Check Gate and Gate Receipt

This is the canonical provider-neutral seam when the child builder hands a Draft
candidate to the parent for the final local Check Gate and ready transition.
The child supplies only the ownership contract and exact candidate commit; it
must not claim local gate PASS/FAIL or Gate Receipt success.

## Ownership contract

Select this mode only after [Check gate discovery](context-and-planning.md#check-gate-discovery)
identifies the policy, exact command, and bootstrap route supporting a passing
exact-candidate receipt. That section owns the existing-gate, missing-dependency,
absent-policy, and gate-creation cases; selection does not require the full gate
to pass before implementation. The child preserves the launch prompt's explicit
`Gate owner` assignment and reports any unresolved feasibility prerequisite to
the parent rather than changing ownership.

```yaml
local_gate_owner: "parent"
builder_gate_status:
  status: "not-run"
  not_run_reason: "parent-owned"
ready_transition_owner: "parent"
```

The parent posts the Gate Receipt and marks ready only after verifying the same
candidate through `forge snapshot` and the target repository Check Gate.

## Stage-correct handoff verification

Consume the [two-line builder handoff](../templates/builder-final-handoff.md) or
[reviewer handoff](../../start-review/templates/reviewer-final-handoff.md) as
locators. Use `forge snapshot` for native claims, author identities, and bindings;
omit optional receipt/report locators until those artifacts exist. A missing
future artifact is not a failed binding. An absent/malformed locator handoff
requires recovery from the bound change request and durable packet, not a guessed
ID, ceremonial note, or retired final delivery block.

| Stage | Required evidence and outcome |
|---|---|
| Before parent gate | Verify issue/change/source/target, pushed candidate and current Lift, required rows, launch-bound Gate owner and `gate_owner_received`, parent-owned/not-run contract, and feasibility. `not-created` is valid; route the candidate to the parent gate without requiring a receipt or independent report. |
| Before ready/review | Require the published/read-back passing exact-candidate Gate Receipt and current Lift; verify receipt identity, authorship/provenance, command, execution evidence, and commit. Missing receipt blocks ready/review. A future independent report is not required to launch its reviewer. |
| Before approval/finish | Additionally require the published independent Review Report for the exact current head, verified author/context, complete review and eligible verdict. Check original finding bindings against their originating reports and apply the authority/caller/common guards separately. Missing report blocks approval/finish. |
| Revision candidate | Rebind candidate/Lift, retain original report/commit/finding tuples, and label old receipt/review artifacts historical. Return to parent gate with `not-created` for the new receipt, even if the change request is already ready; ready state alone cannot authorize re-review or finish. |
| Stale or contradictory claims | An old receipt/report claimed as current, wrong candidate or author, conflicting owner, fabricated ID, or publication/readback mismatch fails closed at the affected transition. Resolve the contradiction; do not treat it as absent future evidence. Historical artifacts cannot satisfy current gate/review eligibility. |

Check every existing artifact presented as current even at pre-gate entry.
Native snapshots remain evidence-only; the parent derives the next stage.
Provider CI remains advisory. None of these routing outcomes changes receipt
validation, authoritative ownership selection, or approval/finish authority.

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
5. Tracked files remain unchanged after the gate. If they changed, the Receipt
   fails: commit them, bind the new exact candidate, and rerun the full gate.
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

With feasibility established, before the receipt the two-line final uses
`not-created`; the parent derives `phase: parent-gate`, next actor `parent`, next
action `parent-run-gate`, with no extra decision. These routing fields remain
available in other supported compact indexes, not builder/reviewer finals.
An unresolved prerequisite instead requires a precise blocked report to the
parent; neither the ownership contract nor an N/A result is a passing receipt.
A Gate Receipt is canonical gate evidence; later description updates are delta-only.
