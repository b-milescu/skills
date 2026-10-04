# Implementation flow

Detailed common implementation sequence for `start-build` builders. This file is the canonical owner of the implementation flow; [check gate discovery](context-and-planning.md#check-gate-discovery) and the [stuck protocol](stuck-protocol.md) own their own sections. Child builders may use the smaller [child-builder path](child-builder.md) unless this full flow is needed.

## Source lifecycle

Select the source lifecycle independently of standalone/child mode. Revision
does not change gate, ready, review-launch, or finish ownership.

| Entry | Source and change request |
|---|---|
| New standalone | Initialize a new source from the verified current remote default; push and open its early Draft once. |
| Allocated child, initial run | Reuse the parent's absolute worktree, source branch, and current head. Allocation already performed initialization; open the early Draft only if this new source has no change request. |
| Standalone revision | Bind the existing change request and clean source checkout at its current head; append fixes and update that change request. |
| Delegated revision | Reuse the allocated absolute worktree and current source head, bind the existing change request, and append fixes under the child's assigned ownership. |

For every entry, require a clean working checkout (`git status --porcelain`
empty), verified repository/source binding, and freshly read work-item and
change-request state/ownership before editing. If dirty or bindings conflict,
stop and reconcile with the owner; never auto-stash, reset, or clean. Preserve
unrelated coordinator work. On reuse/revision, compare local HEAD, remote
source (when published), and provider current commit (when a change request
exists); reconcile mismatches before editing rather than overwriting a head.

Only new source creation initializes from default: fetch the confirmed named
code remote, fast-forward its verified target default, verify HEAD against that
remote/default ref, then create the project-named issue branch. Stop on failed
binding/fast-forward. A parent's verified allocation satisfies this step.
Later remote-default advancement does not invalidate that allocation or an
existing revision source; do not recreate/reset the branch or automatically
rebase it to make HEAD equal the new default.

For revisions, read the originating Review Reports and retain every
`(Report locator, originating Reviewed SHA, Finding ID)` tuple. The current
candidate SHA belongs in Reviewer Lift `Reviewed SHA` and refreshed gate/CI
evidence, never in place of a finding's historical SHA. Continue through the
revision publication and fresh-review handoff in Procedure step 10.

## Procedure

1. Resolve the work item(s) first: supplied or via [issue pickup](issue-pickup.md). If multiple, enter [Multiple issue worktree mode](multiple-worktrees.md) and run the rest independently per worktree.
2. Follow [source lifecycle](#source-lifecycle) before touching the checkout: initialize only a new source, reuse parent allocations and revision sources, and retain the selected mode's ownership.
3. Load narrow context, not the whole repo or conversation: rulebook index, work item, and affected docs/source/tests first. Expand to architecture docs, ADRs, domain docs, or `CONTEXT.md` only from evidence triggers listed in [context and planning](context-and-planning.md#discovery-budget). Record each non-obvious source and relevance reason in the Build Plan Packet or Review Packet.
   Before planning/edits on initial or revision entry, follow [Task-selected specialists](context-and-planning.md#task-selected-specialists).
4. For a new source without a change request (including a parent allocation), open a **Draft change request** early against the default branch after the source exists remotely; for reuse/revision, update the existing change request instead. Use `forge publish` with `../templates/review-packet.md` or `../templates/review-packet-compact.md`; the selected provider owns work-item relationship/closure preview validation, publication, and provider-native readback. Do not mark ready in this step. Initialize the complete **Reviewer Lift** block per `../templates/filling-guide.md`; pending fields are allowed on day one.
   - **Early Draft change-request push.** This push creates the remote source ref and/or Draft handoff. It does not require the full local gate; use Draft status and pending/N/A Reviewer Lift values until evidence exists.
   - **Implementation pushes before ready.** Pre-ready pushes may publish incremental work or refreshed draft evidence. Run targeted checks during the red-green loop, keep Reviewer Lift current with the facts available, and do not request review from Draft state.
5. Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the change request. Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger. Exception categories require a recorded rationale and must not allow fake tests or meaningless checks. Work-item-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice. Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions. Commit coherent green slices referencing the work item/slice; revision commits cite review items such as `MF-1: <fix>`. For docs-only/config-only/mechanical work, state `TDD: N/A` and why — do not fake tests.
6. Test at the smallest public seam that proves the behavior without coupling to internals. Apply test-layer advice when an applicable specialist supplies it; without optional taxonomy guidance, use the workflow/native-test rules. The project's full check gate still runs before requesting review.
7. Run targeted tests during the red-green loop. Never use live product/runtime/operator external systems as regression evidence.
8. Update the change-request description with `forge publish`: diff summary, acceptance-criteria evidence, safety evidence, TDD trace or `TDD: N/A` rationale, and full test/check-gate output or CI locator. Require provider-native publication readback to match the intended artifact. Keep the Reviewer Lift block current as values become available. Use stable `OQ-N` IDs in the body so the reviewer can answer each one.
   Keep finding bindings at `none` until findings are in flight. Preserve each original `(Report locator, Reviewed SHA, Finding ID)` exactly and validate all reports against the current packet with `bun <start-review-dir>/scripts/validate-finding-bindings.mjs`, where `<start-review-dir>` is the resolved absolute path of `../../start-review` (never the target CWD), per `../../start-review/reference/finding-identities.md`.
9. After the ready coverage rule below is satisfied and Reviewer Lift names the current provider commit, use the selected `forge` provider to validate the work-item relationship/closure preview, current-commit binding, and publication readback. Fail closed on missing, incomplete, stale, or mismatched evidence. Then mark ready with `forge act`. In parent-owned gate mode, leave the change request Draft, record the ownership contract from [parent-owned-gate.md](parent-owned-gate.md#ownership-contract), and let the parent follow the Gate Receipt seam before the ready transition.
   Missing, stale, ambiguous, or contradictory finding bindings stop publication and ready-marking before the `forge` common guard.
   - **Ready-marking gate.** The ready coverage rule applies only before marking ready or requesting review. It does not apply to early Draft change-request creation or pre-ready implementation pushes, which stay Draft and must not request review. Run targeted checks during those Draft phases, keep Reviewer Lift current, and re-bind evidence after every push.
   - **Exact-candidate local coverage.** Set `Gate owner` to `builder` or `parent` and `Gate coverage` to `exact-candidate-local`. `Gate coverage rationale` names the gate policy source, exact local command, candidate commit, and result.
   - **Builder-owned gate mode.** The builder may mark ready only after the full local Check Gate passes on the exact candidate, or is explicitly `N/A` with rationale when no local gate can run.
   - **Parent-owned gate mode.** The child records `Gate owner: parent`, the parent-owned/not-run contract, and candidate commit only; [parent-owned-gate.md](parent-owned-gate.md#ownership-contract) owns the parent's gate, receipt, and ready transition.
   - **Advisory CI observation.** Record provider CI locator, status, and commit when available, and attribute a status only when its commit matches the candidate or provider-proven integration commit. Missing, pending, failed, canceled, skipped, stale, wrong-commit, or unavailable CI never changes review, approval, or finish eligibility.
   - **Post-ready push protocol.** If any commit is pushed after ready-marking, publish a provider-native update naming old commit → new commit, reason, changed files, gate rerun, and whether the delta is substantive. Refresh every commit-bound Reviewer Lift field and, in parent-owned gate mode, replace the stale Gate Receipt. Use `../templates/revision-packet.md` for substantive changes.
10. On revision, push new commits and publish exact evidence through `forge`; never resolve a reviewer discussion without verification/project policy. Render one Revision Packet preserving every originating tuple and validate against all reports with `bun <start-review-dir>/scripts/validate-finding-bindings.mjs`, resolved as above. Bare short IDs do not bind findings; no historical identities are rewritten.
    Publish that exact artifact with `forge publish` and require provider-native byte-for-byte readback before handoff. In standalone mode, run a **new** reviewer session per [standalone gate](standalone-gate.md). In child `change-builder` mode, return the revision handoff; the parent orchestrator starts the fresh reviewer.

## Stuck protocol

Stuck handling is canonical in [stuck-protocol.md](stuck-protocol.md): keep the change request Draft, publish `../templates/stuck-packet.md` through `forge publish`, and follow that file's ordered steps.
