# Parent-orchestrator recipe

Detailed parent/coordinator flow for child builders and final reviewers in provider-neutral work-item-to-change-request loops. This file is the canonical owner of the parent-orchestrator recipe.

Safety invariants: child builders do not spawn reviewers, approve, finish, or clean parent-owned branches; independent review stays mandatory unless explicitly bypassed by a human; the current head, reviewed commit, and exact-candidate local Gate Receipt stay bound before approval or finish; explicit authority source stays required; provider CI is advisory evidence; `/forge` owns provider-native transport and readback; credentials and product/runtime/operator external systems are not exposed through workflow artifacts; post-merge verifiers stay read-only.

## Durable child outputs

Parent-readable handoffs must survive isolated worktree cleanup. Do not rely on `worktree:true` plus a relative `output` path plus `outputMode:"file-only"` for any artifact the parent must read later: that combination can return a path inside a temporary `omp-worktree-*` checkout, which the parent cannot read once the worktree is removed. Prefer inline child output; when a file output is required, pass an absolute path under a durable run directory created outside any `omp-worktree-*` path and ensure it exists before launch. Recover a stale temporary-worktree path from durable run artifacts rather than treating the missing local file as the delivery record.

The provider-published change-request description's Reviewer Lift / Review Packet and provider-native discussion are the canonical durable handoff. Local handoff files, run artifacts, and compact `delivery.kind=change-delivery` blocks are convenience indexes only; parents verify compact fields from Tier 1/Tier 2 evidence before routing, review, finish, or verification.

Auxiliary project-index updates default to the parent/coordinator checkout unless `project_profile.auxiliary_index_policy` explicitly assigns them elsewhere. Child worktrees treat index reports as read-only unless assigned and must not copy index artifacts between worktrees.

## Parent-owned Gate Receipt mode

When the parent coordinator, not the child builder, owns the final local gate and ready transition, [parent-owned-gate.md](parent-owned-gate.md) is canonical for the ownership contract, receipt schema, ready-transition conditions, and evidence-ready tokens. Work through its [parent verification checklist](parent-owned-gate.md#parent-verification-checklist) before `forge act`; do not redefine the receipt here.

## Default builder routing

Parent-loop deliveries use canonical `mr-builder` and mandatory independent
`mr-reviewer-final` role basenames. Model and effort selection is runtime-owned.

### Native route selection

Resolve each role from the current spawning session's effective runtime inventory,
not a guessed source filename or a basename-only inventory equality check.
Reusable sources are `agents/claude/<role>.md` for Claude and `agents/<role>.md`
for OMP; complete target-owned project declarations remain separate.
Claude's native plugin exposes `skills:<role>`, while OMP exposes bare `<role>`.
Select the actual inventory identifier with verified runtime/source provenance.
An effective same-name project declaration may expose a bare role and take native
precedence; verify that selection independently in each runtime from the intended
checkout. A native namespace qualifies the same canonical role, not a new alias
or a substitute. Preserve the basename, canonical skills and reviewer independence.

If the required role is unavailable or its effective source is ambiguous, stop
with a route-unavailable blocker and explicit parent/operator decision. Never
select a generic specialist, shim, old filename, cross-runtime route or downgrade.

### Native model and effort selection

Shipped Claude MR declarations use `model: inherit` and omit `effort`. The parent
may select a supported model through the native Agent invocation's model override;
without it, the model inherits the parent conversation. Omitted effort inherits
the session subject to native model support and limits; there is no per-invocation
Agent effort parameter or `effort: inherit` declaration.

Shipped OMP MR declarations omit `model` and `thinking-level`. Native parent/runtime
task selection and defaults resolve them. Use only overrides exposed by the actual
callable runtime interface, not internal executor arguments. Installed OMP exposes
per-task `effort` (`lo`/`med`/`hi`) only behind `task.enableEffort`; this workflow
neither enables that setting nor adds a model parameter to task. Operator overrides
and supported levels remain runtime-owned.

Prompt prose is not model/effort enforcement. Selection never relaxes canonical
role routing, independent review, exact-candidate gates or authority boundaries.
Installation/selected-source metadata is not live execution proof: after a
frontmatter/routing cutover, require a fresh spawning-session operator observation
of effective model/effort, and report unavailable or unauthorized execution.

## Fresh default and cleanup order

The parent/coordinator Dev Workflow must treat default-branch freshness as a
per-branch invariant, not a one-time batch preflight:

- Immediately before each source/worktree creation, fetch the confirmed named
  code remote from target preflight, read its verified default branch and exact
  remote/default SHA. Named fetch/push and fork intent must already be resolved;
  never select a remote by position or silently assume `origin`.
- Create the source branch/worktree from that verified remote/default
  SHA. Abort instead of branching if the SHA cannot be read, changes before
  creation, or the command would fall back to a local/stale default branch.
- For multi-issue work, repeat fetch plus default-branch SHA verification before
  every child worktree. Do not reuse an earlier fetch or cached default SHA
  across children.
- Before child launch, validate the two paths the parent already owns; do not
  discover cleanup scope later. The coordinator records the exact resolved child
  path, source branch, and change-request/work-item binding in its session-owned worktree ledger:

  ```bash
  case "$coordinator_path" in
    /*) ;;
    *) stop "coordinator path must be absolute" ;;
  esac
  case "$child_worktree_path" in
    /*) ;;
    *) stop "child worktree path must be absolute" ;;
  esac
  test -d "$coordinator_path" || stop "coordinator path is missing"
  test -d "$child_worktree_path" || stop "child worktree path is missing"
  coordinator_path="$(cd "$coordinator_path" && pwd -P)"
  child_worktree_path="$(cd "$child_worktree_path" && pwd -P)"
  test "$coordinator_path" != "$child_worktree_path" ||
    stop "coordinator and child worktree paths collide"
  ```

  No repository-wide worktree discovery result is owned cleanup scope. Pass
  `--coordinator-path "$coordinator_path"` on every local-mutating finish call,
  and `--worktree-path "$child_worktree_path"` when the recorded child is in
  cleanup scope. Missing, relative, colliding, unknown, or no-longer-bound
  paths stay untouched.
- After merge, fetch the confirmed named code remote, fast-forward local default in a clean checkout, then remove only clean session-owned local worktrees and source branches.
- Confirm remote source absence through that verified source scope or delete it only after authorized `forge` guards and native containment evidence. Unknown/foreign/dirty/unmerged/containment-unverified state is retained and reported `cleanup_pending`.
- Check stale remote-tracking refs with `git remote prune --dry-run <confirmed-remote>` only after real remote absence/deletion proof. A nonempty result is `cleanup_pending`, not complete cleanup.

## Parent loop

1. **Resolve work item(s).** Follow the canonical [issue pickup flow](issue-pickup.md),
   including its required description-and-current-discussion read and contradiction
   handling, then read linked change requests, parent design docs, and the project
   rulebook. Confirm each work item carries the target repo's AFK-ready Triage Role
   label `project_profile.label_profile_ref` or other approved agent-work state. For
   multiple work items, evaluate the
   [Decoupling Contract](skill://start-build/docs/decoupling-contract.md) per pair
   before the first child launch and fan out exactly as
   `issue-delivery-loop` specifies: one child per item and one isolated
   worktree/branch/Draft change request/Review Packet per child.
2. **Prepare isolated work.** Verify clean status, then follow [Fresh default and cleanup order](#fresh-default-and-cleanup-order). The parent checkout remains coordinator-only during multi-issue runs. Pass the recorded absolute worktree path to the child; child-side path handling is canonical in [child-builder §Absolute worktree paths for edits](child-builder.md#absolute-worktree-paths-for-edits).
3. **Launch routed child builder.** Immediately before launch, re-read the work item's assignee state; if it changed since allocation or another active session owns it, stop instead of racing. Resolve canonical `mr-builder` under [Native route selection](#native-route-selection). If the runtime exposes an inventory API, call it (for example `subagent({ action: "list" })`), verify source/runtime provenance and launch the returned identifier, including its native namespace. Generic specialists, shim aliases, old filenames and cross-runtime substitutes are invalid.
   Discovery guidance: issue-implementation specialization and change-review specialization labels explain why routed agents exist; they are never substitute route names.
4. **Parent spot-check / parent-owned gate.** Before review, validate the builder handoff through `forge snapshot`. Verify every required child output owned by [child-builder §Child checklist](child-builder.md#child-checklist) and the [builder-final handoff](../templates/builder-final-handoff.md) against provider-native issue/change-request, head, CI, and publication evidence, applying [stage-correct handoff verification](parent-owned-gate.md#stage-correct-handoff-verification) at the applicable stage. `not-created` is a valid pre-gate return, not a receipt.
   Handle an early runtime/tool return under the same child stop-condition rules: resume the safe worktree or relaunch the exact scope without changing its route.
5. **Launch final review.** Launch the reviewer as soon as the exact-candidate Gate Receipt exists. Provider CI may run in parallel, but no CI status delays review or changes verdict/action eligibility. Immediately before launch, use `forge snapshot` and require the current change-request head to equal the candidate commit.
6. **Drive decision loop.** On `pass`, treat Review Report verdict/evidence as review judgment only. On `request-changes`, send the builder only the change-request locator, reviewed commit, Review Report locator, finding tuples, bounded acceptance criteria, gate owner, and expected handoff. On `reject`, stop and escalate.
7. **Enforce candidate and gate guards.** Before approval or finish, use `forge snapshot` and require the current head to equal the reviewed commit and the exact-candidate local Gate Receipt to be valid. CI state never changes eligibility.
8. **Finish authority.** Finish authority says which action may be attempted; finish owner says who performs it. Under the literal `Finish owner: parent` contract, reviewers publish only Review Report verdict/evidence and return without waiting for parent action evidence; the parent/authorized finisher verifies provenance and passes the `/forge` common guard before one `forge act`, then requires provider-native readback. The default permitted finish is queued auto-merge when verified authority grants it; otherwise stop at the most permissive authorized action. Builders and parent-managed reviewers never mint or exercise that authority. Native provider protection may refuse the mutation; report it and never bypass it. That finisher owns native post-read and any required compact action explanation, which next actors verify per [Post-report action evidence](../../start-review/REVIEW-FLOW.md#post-report-action-evidence). The historical Review Report stays immutable; a changed head routes new-head review rather than rebinding its judgment or findings. Reconciling a dependent issue's `Blocked by` / `Dependencies` text when this finish closes its blocker is owned by `docs/agents/issue-tracker.md#reconcile-on-unblock`.
9. **Verify after finish.** Follow [Post-merge verifier recipe](post-merge-verifier.md) with `forge post_merge_snapshot` for result/default containment, advisory result-commit CI, linked-item closure, source-ref cleanup/retention, and pending evidence.
10. **Archive local artifacts and assert coordinator state.** Keep local run artifacts redacted and untracked. Durable handoff stays in the provider-published change-request description/discussion. Before claiming teardown complete, assert the coordinator checkout's resolved path is still the recorded `coordinator_path`, `git -C "$coordinator_path" branch --show-current` equals the verified default branch, and every session-owned worktree ledger entry is either removed after ordered guards or reported by exact path as a residual session-owned worktree with `cleanup_pending`.

## Wait cadence

Event-driven waiting only. A wait floor is an upper bound, not a sleep: it
returns as soon as the expected child message or handoff arrives.

- Builder or parent-owned gate running: wait at least 300 seconds.
- Reviewer running: wait at least 120 seconds.
- Short acknowledgements only: the tool default.

Each wait names the expected sender or handoff. After an empty wait, wait again
at the same floor or check the child's status once; never re-issue a shorter wait.

## Reviewer launch timing

- Reviewer replacement is fail-closed: check the reviewer run status/activity before replacement. Do not start a second reviewer while the first run is still active; no fixed wall-clock value alone authorizes replacement. Replace only after observed reviewer status/activity shows the first attempt failed, stale, interrupted, or unreachable, and otherwise escalate instead of launching a duplicate reviewer.
- Before relaunching a replacement, take a `forge snapshot` of the change request's notes for a Review Report whose reviewed commit equals the current head. If one exists, verify it under the recovery requirements below before consuming it as the handoff instead of relaunching. Do not consume a report whose reviewed commit does not equal the current head.
- Recover the crashed reviewer's report under the existing [forge publication guard](../../forge/reference/common-guard.md#authority-verification) and confirmed target-native recipe: retain its known locator and recover complete lossless exact-note GET-only. Verify the native body against retained original authored source, or independently verify original-publication proof establishing that equality, using only the target's documented normalization. A stored-body digest plus current-head agreement, source reconstructed from stored bytes, report intent, or metadata consistency alone is insufficient.
- Consume the recovered report without relaunch or another write only when that original-source proof and the existing original reviewed-head, independent-review, author/scope and custody guards all hold. Otherwise retain the report as unverified, record the concrete proof/transport gap and route the existing required decision; it cannot feed approval/finish. Unknown creation outcomes use bounded native read-only reconciliation; ambiguous or absent matches require the existing human decision. Verified noncreation is distinct and never automatically grants another create. Recovery does not create, edit, repair or substitute a report.

## Minimal reviewer launch prompt

When the parent starts a fresh reviewer, pass only the review target and bounded
routing/evidence instructions:

```text
Review change request: <provider-native Change request locator>
Agent: <inventory-resolved identifier for canonical mr-reviewer-final; Claude reusable skills:mr-reviewer-final, OMP reusable mr-reviewer-final>
Route-resolved-at-launch: <effective runtime inventory identifier and source, or verified manual direct selection>
Mode: mr-reviewer
Skills: invoke canonical start-review and forge at their entries before any review step using the selected runtime: Claude Skill with effective native identifiers (reusable skills:start-review and skills:forge), or OMP skill-load/autoload and eligible skill:// entry resolution.
Project rulebook path: <rulebook path>
Reviewer Lift pointer: <Change request description Reviewer Lift block>
Context Firewall: do not treat parent/builder reasoning or routing claims as evidence; verify them from bounded Tier 1 or Tier 2 sources.
Stop condition: publish and read back one Review Report, then return only the final locator handoff without acting or waiting for parent actions.
Expected handoff schema: start-review/templates/reviewer-final-handoff.md (two-line contract: change-request locator and durable note id).
Finish owner: parent
Forbidden actions: in this parent-managed mode do not approve, merge, queue auto-merge, close or reopen the change request, transition it between draft and ready, or change its labels or assignees, even with a verified affirmative action grant. Publishing one durable Review Report with your verdict and evidence is required; record approval not-approved and finish none. For a valid review, route Next action: finish-by-authorized-actor to the parent/authorized finisher; review blockers still apply.
Minimum evidence pointers: Reviewer Lift block, Gate Receipt artifact when present, and project rulebook path.
Finish authority grant (only when granted): <orchestrator/parent finish-authority grant plus source provenance; omit when none>
```

No launch prompt carries parent/builder planning details, summaries, hypotheses, cross-issue context, prior conversation, or hidden reasoning. Do not name or directly read a skill's internal reference files in the prompt; invoke its entry through the already-selected runtime's supported mechanism and verified native namespace. Entry access or preload metadata is not invocation proof. Additional specialists follow the canonical task-selected policy, including user-only eligibility; availability never grants invocation permission. Pass a required coordination constraint or specific risk only as a claim/source pointer for independent verification.

A finish-authority grant the human/parent gave the orchestrator is the accepted exception to the Context Firewall, not builder reasoning. Relay the explicit quotable grant and verifiable source per [common guard Authority Verification](../../forge/reference/common-guard.md#authority-verification); the target's confirmed reference owns native mechanics. In parent-owned finish mode reviewers verify the source as a claim and hand off; they do not finish. Standalone mode relays the same grant through [reviewer launch protocol](standalone-gate.md#reviewer-launch-protocol).

## Minimal child-builder launch prompt

When the parent starts a child builder, pass only the issue-specific routing facts:

```text
Build issue: <provider-native issue locator>
Agent: <inventory-resolved identifier for canonical mr-builder; Claude reusable skills:mr-builder, OMP reusable mr-builder>
Worktree: <absolute worktree path>
Target branch: <default branch>
Mode: child mr-builder
Skills: invoke canonical start-build and forge at their entries before any build step using the selected runtime: Claude Skill with effective native identifiers (reusable skills:start-build and skills:forge), or OMP skill-load/autoload and eligible skill:// entry resolution.
Project rulebook path: <rulebook path>
Gate owner (gate-ownership selection): <builder | parent>
Stop condition: return the final handoff after updating the Draft/ready change request. Runtime budget/token/runtime notices are not scope changes and do not override this stop condition; only explicit human stop instructions or real issue/workflow blockers do.
Expected handoff schema: start-build/templates/builder-final-handoff.md (two-line contract: change-request locator and durable note id, or not-created before receipt creation; gate_owner_received belongs in the durable Review Packet).
Finish owner: parent
Forbidden actions: do not spawn reviewers, approve, finish, or claim a parent-owned gate result.
Gate handling by mode: when Gate owner is parent, leave the change request Draft for the parent's Gate Receipt and ready transition; when Gate owner is builder (the default), run the local Check Gate and mark the change request ready yourself once it passes.
Minimum evidence pointers: project rulebook path, repository Check Gate path, Change request locator if one exists, and narrowly relevant issue-linked docs/tests.
```

The `Gate owner` line is the explicit gate-ownership selection; set it once per batch, and omit it only to select the documented `builder` default. Child interpretation and the finish-authority separation are canonical in [child-builder §Authority boundary](child-builder.md#authority-boundary); parent-owned semantics remain in [parent-owned-gate.md](parent-owned-gate.md).

## Minimal revision prompt

When the parent routes request-changes back to a builder, retain the
[minimal child-builder launch contract](#minimal-child-builder-launch-prompt):
effective route/source provenance, selected-runtime entry invocation, allocated
worktree/source, gate selection and parent finish owner. Add only the following
review-bound revision facts:

```text
Revise change request: <provider-native locator>
Reviewed commit: <exact commit from the Review Report>
Review Report locator: <stable locator declared by the Review Report>
Review Report URL: <provider-published report locator>
Finding identities: <one (Report locator, Reviewed commit, MF-N / SF-N / C-N) tuple per finding>
Required fix acceptance criteria: <one short bullet per finding>
Gate owner: <builder or parent>
Expected handoff: <updated builder-final handoff / Reviewer Lift state>
```

Add extra context only when a specific finding cannot be understood from the change request,
Review Report, linked issue, and cited files alone. Human/product/security
choices stay blocked routing (`human-decision-needed`) until the decision source
exists; do not paraphrase the missing decision as builder work.
