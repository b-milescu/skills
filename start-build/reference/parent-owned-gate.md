# Parent-owned Check Gate and Gate Receipt

This is the canonical provider-neutral seam when the child builder hands a Draft
candidate to the parent for the final local Check Gate and ready transition. The
child supplies only the ownership contract and exact candidate commit; it
must not claim local gate PASS/FAIL or Gate Receipt success. For
`Gate owner: builder` this file also owns the
[Builder-owned Gate Receipt](#builder-owned-gate-receipt).

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

Check every existing artifact presented as current, even at pre-gate entry.
Native snapshots stay evidence-only; the parent derives the next stage, and no
routing outcome changes receipt validation, ownership selection, or
approval/finish authority.

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
  status_before: "draft"        # or "ready" when re-gating a ready change request
  status_after: "ready"
  command: "<project Check Gate command>"
  result: "PASS"
  summary: "full project Check Gate completed successfully"
  preflight_checks:
    - name: "clean-status-before"
      command: "git status --porcelain --untracked-files=all"
      result: "PASS"
      summary: "empty"
    - name: "tracked-files-unchanged-after"
      command: "git status --porcelain --untracked-files=all"
      result: "PASS"
      summary: "empty"
  evidence:
    - tier: "tier-1"
      kind: "local-gate"
      source: "opaque artifact locator"
      summary: "command, checkout commit, and result"
  observed_at: "2026-06-01T00:00:00Z"
```

`status_before` records the change request's actual pre-gate state: `draft`, or
`ready` when re-gating a change request that is already ready. Both are accepted;
copying `draft` into a re-gate of a ready change request publishes a false field.

Both preflight rows above use the stronger accepted form
`git status --porcelain --untracked-files=all`. Prefer it: it names every
untracked file individually instead of collapsing an untracked directory to one
entry, so generated residue inside a directory is reported rather than
summarized. The bare `git status --porcelain` is still accepted. Neither form
reports gitignored paths, so where ignored residue can refuse a gate — a
generated `node_modules/` tree, for example — check it separately with
`git status --porcelain --untracked-files=all --ignored=matching -- <paths>`
rather than by altering the preflight rows.

### Publication syntax and proof

Publish the receipt as block-style YAML as above: a standalone `gate_receipt:`
anchor with indented child fields. JSON text merely placed inside a YAML fence
is not the publication form; JSON MCP arguments are transport, while the YAML
receipt body is the durable artifact. Valid YAML for the full local validator
need not be recognized correctly by the current native extractor, so arbitrary
scalar spellings are not proven supported. Keep the actual project gate command
unchanged.

Three checks stay separate: full local pre-post receipt validation; native
extraction of the exact `checkout_commit`, `command`, and `result` with
candidate binding; and post-note validation of that same receipt and current
Lift. Anchor recognition or SHA equality alone proves none of receipt validity,
execution, an unchanged checkout, authorship, independent review, or authority.

Retained local-log custody (issue #490): when a `local-gate` evidence row's
`source` names the retained local log by absolute filesystem path, the
validator requires that exact file to be readable — at pre-post validation,
before any publication or ready action, and again at post-note validation.
Native/remote evidence locators (`scheme://` URLs) keep their documented
behavior and are never opened as local filenames. A missing or unreadable
retained log refuses the receipt with a diagnostic naming the source and the
corrective action: retain and verify the original run's evidence before
publication, and if custody failed, recover it with explicit original-run
provenance — never pass a replacement run off as the historical one. A
readable log permits the check to proceed but by itself proves no gate PASS,
exact-candidate binding, clean checkout, review, or authority; the other
checks on this page still apply.

Render once, validate before publication, publish with `forge publish`, and
require provider-native byte-for-byte readback. Then validate the same artifact,
its returned locator, and the current Review Packet before ready:

```text
node skill://start-build/scripts/validate-gate-receipt.mjs --mode pre-post --receipt <receipt> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-command <command>
node skill://start-build/scripts/validate-gate-receipt.mjs --receipt <receipt> --review-packet <packet> --change-id <id> --issue-id <id> --reviewed-commit <commit> --gate-receipt-locator <the sole URL in the Reviewer Lift `Local gate` row> --gate-command <command> --gate-policy-ref <policy>
```

`--gate-receipt-locator` is not an opaque value: it must equal, byte for byte,
the sole `scheme://` URL the Reviewer Lift's `Local gate` row carries — the
published note's full URL, not a bare note id. Sole, not first: a row carrying
two or more URLs extracts no locator at all and fails. A mismatch is reported as
`Gate Receipt pointer mismatch`, naming the argument and the token read from the
row, separately from the row's missing-`PASS`, contradictory-token, and
missing-gate-command failures.

Post-note validation also refuses off-schema values (issue #501) in every
Reviewer Lift row whose value set
[reviewer-lift-schema.md](../templates/reviewer-lift-schema.md) closes:
`Review gate`, `Change tier`, `Transport` (may be absent), `Gate owner`,
`Gate coverage`, `CI pipeline`, `Touched safety surfaces`,
`Acceptance surfaces`, `Decoupling proof`, `Open Questions`,
`Approval authority`, and `Finish authority`. Post-note validates a
parent-owned Lift, so `Gate owner` must lead with `parent`; the annotation after
it (for example `parent — parent-owned/not-run; candidate <sha>`) may stay after
the receipt, while `builder`, `parent-owned`, or `both` is refused (issue #502).
A separator must be followed by real text (`moderate ()` and `N/A ()` are
refused), and a `Change tier` rationale is not another tier token. `CI pipeline`
needs a locator or a `#<n>`/`pipeline <n>`/`run <n>`/`build <n>` ID (a bare
count is not one) and a SHA; a hex-letter word such as `defaced` is not a SHA.
`Decoupling proof` names a co-running change request (`!<n>`, `#<n>`,
`MR <n>`, or a `merge_requests/<n>`, `pull/<n>`, or `pullrequest/<n>` locator)
or a branch-shaped name (`issue-<n>…`, or after `branch` a code span or a token
with `/`, `-`, `_`, or a digit; never `none`). Each refused row is listed once
with its accepted forms; cell values are not echoed. Free-text rows are not
judged, and `Finding bindings` stays with `validate-finding-bindings.mjs`.

After publishing the Gate Receipt, rebind both `Local gate` and `Gate coverage rationale`.
For `Gate coverage rationale`, replace only the `result:` token: `not-run — parent-owned` becomes `PASS — Gate Receipt <locator>`.
Leave policy, command, candidate, and `coverage exact-candidate-local` unchanged.
`Local gate` still requires `PASS`, one locator, and no `not-run`.

## Builder-owned Gate Receipt

When the launch prompt selects `Gate owner: builder` (the documented default in
[child-builder.md](child-builder.md#authority-boundary)), the builder — not the
parent — runs the full local Check Gate on the exact candidate and publishes the
receipt itself. This section owns that contract so the two ownership modes
cannot drift apart.

The builder-owned receipt is one change-request note whose body carries a
yaml-fenced block with a standalone `gate_receipt:` anchor and exactly these
child fields:

```yaml
gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "builder"
  checkout_commit: "<exact candidate commit the gate ran on>"
  command: "<full project Check Gate command>"
  result: "PASS"
```

The note title honestly names the builder as receipt owner (no parent or
provider impersonation), and the note body carries evidence bullets for the
gate run (command, commit, result, checkout provenance). Prose or table-formed
receipts and YAML alias anchors (`gate_receipt: &gate_receipt`) are invalid;
the anchor must be the plain mapping key. Builder receipts do not carry the
parent-only fields (`change_id`, `issue_id`, `checkout_path`, `status_*`,
`preflight_checks`, `evidence`) — those belong to the parent schema above.

Acceptance is provider-native and exact-candidate: the handoff-evidence tool
must report `present_anchor: true` and `receipt_commit_eq_head: true` for the
current head, and publication requires provider-native byte-for-byte readback
of the note. Validate locally before publication (parent-owned binding flags
are rejected in this mode; full post-note Reviewer Lift validation stays scoped
to parent-owned mode):

```text
node skill://start-build/scripts/validate-gate-receipt.mjs --owner builder --mode pre-post --receipt <receipt> --reviewed-commit <commit> --gate-command <command>
```

Fail-closed floors are unchanged: a receipt bound to any commit other than the
current candidate is stale evidence, a wrong owner or malformed anchor fails,
and any push invalidates the receipt until a new exact-candidate receipt
exists. The builder then returns the read-back-verified receipt note id in the
two-line handoff ([builder-final-handoff.md](../templates/builder-final-handoff.md)).

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
ready and launch independent review. Provider CI is advisory and never changes
pass or finish eligibility. Literal byte-for-byte acceptance strings receive
targeted exact-string evidence, which does not substitute for independent
reviewer verification.

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
`not-created`, and the parent derives `phase: parent-gate` / next actor
`parent` / next action `parent-run-gate` with no extra decision.
An unresolved prerequisite instead requires a precise blocked report to the
parent; neither the ownership contract nor an N/A result is a passing receipt.
A Gate Receipt is canonical gate evidence; later description updates are delta-only.
