# Check Gate ownership and handoff

This is the canonical provider-neutral ownership, stage-transition and
execution-context/reuse interface. A parent-owned child supplies only the
ownership contract and exact candidate commit; it must not claim local gate
PASS/FAIL or Gate Receipt success.

Gate executors read [gate-receipt.md](gate-receipt.md) before running the gate;
parents and reviewers verifying a receipt read it before relying on a PASS for
ready, review, approval or finish. It owns receipt schemas, extraction,
production/publication and validation for both owners. A parent-owned child
needs only this interface and its [receipt-independent Lift check](child-builder.md#reviewer-lift-child-seam-rule)
before pre-gate handoff, not receipt-production mechanics. The read-only
post-merge verifier keeps its [own recipe](post-merge-verifier.md).

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

## Execution-context binding and reuse

This contract applies to both gate owners. Before a run, resolve the target gate
policy's relevant external source/input identities, gate configuration and
toolchain bindings, including how to verify them. The target owns that scope;
do not infer a universal dependency set. When no additional inputs are relevant,
record the policy source and its scoped rationale. Missing policy or required
context proof is unknown, not an empty dependency set.

The selected gate owner records the original run's verifiable, non-secret
identities and policy source alongside its candidate, command and execution
evidence. Use the target's declared identity method, such as an immutable source
revision, input artifact digest, configuration identity or actual toolchain
release/dependency identity. Bind what the run actually used, not values observed
only later. Retain the original evidence and its custody:

- **Parent-owned:** use existing receipt `evidence` source/summary and retained
  run evidence for the declared bindings.
- **Builder-owned:** use the receipt note's existing evidence bullets and their
  retained run evidence, outside the restricted receipt YAML.

No receipt or Reviewer Lift fields are added. The receipt validator does not
discover or compare this context. Collect only target-declared, non-secret
identities through authorized evidence routes; no environment dumps, credential
values, generic fingerprint scanner or automatic external/product probes.

Before reusing a PASS for ready, review, approval or finish, resolve the current
packet and native candidate, then compare the original run's declared bindings
with independently verified current bindings under the applicable target policy.
Verify that the run stayed within that declared envelope; missing, ambiguous or
unverifiable required proof prevents reuse. A changed relevant input,
configuration, toolchain or policy scope invalidates reuse even when candidate
SHA and command are unchanged. Matching bindings are necessary, not proof of
execution or PASS: receipt validation, exact-candidate execution evidence and
custody, native freshness, authored-source/readback equality, independent review
and authority checks all remain required.

On a changed or unproven envelope, the selected gate owner must obtain newly
bound execution evidence and publish a new receipt under the existing guards
before dependent ready/review/approval/finish can proceed. Missing prerequisites
block that stage; this rule neither changes ownership nor authorizes automatic
reruns or live reads. Do not relabel an old run with current identities. Keep old
receipts and reports immutable and historical, refresh the current packet's
evidence pointers, and obtain new independent verification of any behavioral
review evidence invalidated by the context change.

## Stale exact-SHA evidence fails closed after a revision push

Any push makes older-commit local gate, CI, review, and Gate Receipt pointers
stale evidence until rebound. Parent-owned mode requires a new exact-commit Gate Receipt
before another ready/review handoff.

## Evidence-ready tokens

- `packet-home-reviewer-lift-current`
- `candidate-commit-pushed`
- `gate-receipt-exact-commit-pass`
- `ready-transition-post-reread`

With feasibility established, before the receipt the two-line final uses
`not-created`, and the parent derives `phase: parent-gate` / next actor
`parent` / next action `parent-run-gate` with no extra decision.
An unresolved prerequisite instead requires a precise blocked report to the
parent; neither the ownership contract nor an N/A result is a passing receipt.
A Gate Receipt is canonical gate evidence; later packet updates are delta-only.
