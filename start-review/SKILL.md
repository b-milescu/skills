---
name: start-review
description: >-
  Reviews one change request in the invoked target's confirmed integration against project
  rules, safety invariants, complete diff/discussions, local Gate Receipt, advisory CI, and TDD evidence.
---

# Start Review

Review one bound change request from a fresh context. A Review Packet, Reviewer
Lift, Gate Receipt, parent/builder prose, and compact delivery block are maps,
not proof. Verify every safety-critical claim from provider-native Tier 1 or
repository Tier 2 evidence. Never review work you built, planned, revised, or
parent-orchestrated.

## Procedure

1. Read the project rulebook and [REVIEW-FLOW.md](REVIEW-FLOW.md).
   Invoke `forge preflight` to bind provider, canonical repository, default
   branch, opaque change-request identifier/locator, source/target, current
   commit, caller identity, and policy profile before snapshot, publication, or
   action. Ambiguity, profile mismatch, or a bare cross-repository identifier
   fails closed.
2. Use `forge snapshot` for the linked issue, current change-request commit,
   complete paginated diff/files, every discussion/thread/review, the
   exact-candidate Gate Receipt, and available advisory CI evidence. Bind the
   checkout and every decision to the lifted `Reviewed SHA`. Missing pages,
   unresolved required discussion, stale head, or incomplete mandatory evidence
   blocks review; absent or incomplete CI does not.
   Before substantive judgment, independently follow
   [Task-selected specialists](../start-build/reference/context-and-planning.md#task-selected-specialists)
   from this verified issue/diff.
3. Copy every Reviewer Lift row into the Review Report as a claim. Verify scope,
   issue acceptance, Gate Receipt/local gate, changed paths, safety and
   acceptance surfaces, TDD evidence, open questions, and authority provenance.
4. Read the full diff, then trace only evidence-linked callers and invariants.
   Findings use stable `MF-N`, `SF-N`, or `C-N` IDs bound to the Report locator
   and exact reviewed commit. Suspected secrets or a partial review fail closed
   without reproducing sensitive content.
   Fill the Review Report `Decision Summary`: Review verdict
   (`pass / request-changes / reject / blocked`), Report locator, reviewed commit,
   CI status / commit, MF-N/SF-N/C-N findings, local checks, Approval action,
   Finish action, Action blocker, Next action, and Report link.
5. Take final `forge snapshot` reads immediately before publication. If the
   current commit changed, do not publish a stale verdict. Render one Review
   Report, use `forge publish` to create one durable non-blocking report artifact,
   and require byte-for-byte provider-native readback.
6. Keep verdict, approval, finish, action blocker, and next action separate.
   `request-changes` and `blocked` never approve or finish. `reject` publishes the Review Report, then stops and escalates. `pass` permits approval only when authority, exact-candidate local gate/Gate Receipt, and open-question policy allow it.
   For a `request-changes` verdict, record approval `not-approved`, finish `none`,
   action blocker `none`, and next action `revise`; `other` is only for a blocker
   no listed token names and requires a one-line Action / Blocker reason.
7. `Finish owner: parent` returns after report publication without acting or
   waiting. Otherwise, before any approval or finish, re-run `forge snapshot`
   and the ordered common guard through one `forge act`. Perform exactly one
   authorized action bound to the reviewed commit or provider-proven integration
   candidate. The actor owns native readback and any required backlinking note
   under [Post-report action evidence](REVIEW-FLOW.md#post-report-action-evidence).
   A changed head denies action and routes fresh review; queued is not merged.
8. Emit the complete reviewer-final handoff. Post-merge verification is a
   separate read-only actor using `forge post_merge_snapshot`.

## Decision floors

- Single-change-request review is the default and preferred mode: one change
  request per fresh reviewer session, full-diff coverage, and no grouped approval.
- Provider CI is advisory. Record a status only with its commit binding; pending,
  failed, canceled, skipped, missing, stale, wrong-commit, or incomplete CI
  never changes review, approval, or finish eligibility.
- Approval authority is `default-after-pass` only with a stable repository policy source.
  Finish authority is separate, affirmative, action-specific, and never inferred;
  missing Finish authority blocks only finish.
- Builders never self-approve or self-finish. A reviewer acts only when the
  Context Firewall, caller identity, provider guard, and exact-commit evidence
  all pass.
- Incomplete coverage returns `blocked` / `partial-review`; suspected credential
  exposure returns `blocked` / `secret-exposure-suspected`. Neither permits
  approval or finish.
- Treat style-only preferences as non-blocking. Correctness, safety, incomplete
  evidence, unresolved required review, credential exposure, and contract
  violations are blocking. The blocking set is otherwise bounded by the
  delivered work item's acceptance criteria per
  [Findings and tone](REVIEW-FLOW.md#findings-and-tone).

Use [review-report.md](templates/review-report.md) and
[reviewer-final-handoff.md](templates/reviewer-final-handoff.md).
