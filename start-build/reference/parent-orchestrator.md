# Parent-orchestrator recipe

Detailed parent/coordinator flow for child `mr-builder` and `mr-reviewer` GitLab issue-to-MR loops. The stable compatibility anchor remains [BUILD-FLOW.md §Parent-orchestrator recipe](../BUILD-FLOW.md#parent-orchestrator-recipe). Project rulebooks and `project_profile` hooks may specialize labels, local gates, branch naming, CI jobs, domain docs, release/deploy policy, manual validation, auxiliary indexes, merge authority defaults, merge authority source requirements, run artifact paths, and post-merge checks, but must not weaken the safety invariants in this flow.

Safety invariants: child builders do not spawn reviewers, approve, merge, queue auto-merge, or clean up parent-owned branches; independent review stays mandatory unless explicitly bypassed by a human; reviewed SHAs and exact-SHA CI results stay bound to the MR head before approval or merge; explicit authority source stays required; MCP-first transport correctness plus help-first `glab` fallback correctness is preserved; credentials and product/runtime/operator external systems are not exposed through workflow artifacts; post-merge verifiers stay read-only.

## Durable child outputs

Parent-readable handoffs must survive isolated worktree cleanup. Do not rely on `worktree:true` plus a relative `output` path plus `outputMode:"file-only"` for any artifact the parent must read later: that combination can return a path inside a temporary `omp-worktree-*` checkout, and parent reads can fail after the worktree is removed.

Safe patterns:

- Prefer inline child output for the parent handoff when size permits.
- If a file output is required, have the caller create a durable run directory outside any `omp-worktree-*` path, then pass an absolute output path under that directory and ensure the parent directory exists before launch.
- If a child returns a stale temporary-worktree output path, recover from async run logs or other durable run artifacts when available; do not treat the missing local file as the canonical delivery record.
- For GitLab delivery, the MR description's Reviewer Lift / Review Packet and GitLab comments are the canonical durable handoff. Local handoff files, run artifacts, and compact `delivery.kind=gitlab-delivery` blocks are convenience indexes only; parents must verify compact fields from Tier 1/Tier 2 evidence before using them for routing, review launch, finish, or verifier decisions.

Auxiliary project-index updates default to the parent/coordinator checkout unless `project_profile.auxiliary_index_policy` explicitly assigns them elsewhere. Child worktrees treat index reports as read-only unless assigned and must not copy index artifacts between worktrees.

## Parent-owned Gate Receipt mode

Use this mode when the parent coordinator, not the child builder, owns the final local gate and ready transition. The canonical ownership contract, Gate Receipt schema, parent verification checklist, ready-transition conditions, and evidence-ready tokens live in [parent-owned-gate.md](parent-owned-gate.md). Parent-orchestrator steps point there instead of redefining the receipt.

Before marking ready, follow the [parent verification checklist](parent-owned-gate.md#parent-verification-checklist): bind the exact candidate SHA from the child/MR, run the target repo Check Gate on that checkout, post a Gate Receipt MR comment, and verify the MR head still matches before the ready mutation.

## Skill-only model-tier routing

This routing is enforced only for flows launched through this parent loop. Manual direct agent selection is outside this enforcement surface; selected agent frontmatter owns the model/effort pin. The parent consumes the delivery tier classified by `skill://issue-delivery-loop/SKILL.md`, or classifies with the same criteria when called directly, immediately before the child/reviewer launch seam.

- `trivial` requires all criteria to be true: docs/prose/templates/labels/inventory/checklist or other mechanical no-runtime work; no runtime behavior; no security/auth/permissions/billing; no schema/migration/persistence; no deploy/runtime/CI semantic change; no concurrency/state-machine/locking impact; no broad architecture/cross-file coupling; no broad multi-file or shared-harness test refactor; clear acceptance criteria.
- `high-risk` applies when any trigger is present: auth/security/crypto/secrets; migrations/schema/data-loss; deploy/runtime/infra/CI semantics; concurrency/locking/state machines/queues; billing/permissions/access control; large diff (`>=20` files or `>=1000` diff lines); unclear acceptance criteria.
- `moderate` is the default when work is neither `trivial` nor `high-risk`.

Test surface alone does not lower the tier: route by blast radius, not by runtime-vs-test surface. A broad test-only refactor — many touched test files (objective signal: `>=10` test files) or a shared test-harness / cross-file test-coupling change — is **not** `trivial` even though it is test-only and runs no runtime code; route it at least `moderate` so a large semantic test refactor takes the higher-effort build/review path instead of bouncing through avoidable review rounds. (A broad test refactor that also trips a `high-risk` trigger above — for example `>=20` touched files — still routes `high-risk`.) This rule only refines tier classification; the canonical per-tier route-name table below is unchanged.

Route exact agent names from the tier. Builders are the same in both runtimes; the final reviewer and the optional scout are runtime-specific because the GPT routes exist only on OMP:

| Tier | Builder agent | Optional scout (OMP runtime only) | Final reviewer (by runtime) |
| --- | --- | --- | --- |
| `trivial` | `mr-builder-sonnet-low` | `mr-review-scout-gpt54-low` non-gate scout only; cannot satisfy independent review | `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP |
| `moderate` | `mr-builder-opus48` | none | `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP |
| `high-risk` | `mr-builder-opus48-high` | none | `mr-reviewer-opus48-xhigh` on Claude Code or `mr-reviewer-gpt55-xhigh` on OMP |

Claude Code has no `openai-codex/*` route: it uses `mr-reviewer-opus48-xhigh` as the primary Claude Code final-review route for every tier and has no optional scout. On OMP, provider-failure fallback to `mr-reviewer-opus48-xhigh` requires an explicit parent/operator decision token after the `mr-reviewer-gpt55-xhigh` route is unavailable; never describe or select it as a cost downgrade or weaker-effort substitute.

## Fresh default and cleanup order

The parent/coordinator Dev Workflow must treat default-branch freshness as a
per-branch invariant, not a one-time batch preflight:

- Immediately before each source-branch creation or `git worktree add`, run
  `git fetch origin`, read the default branch with the Agent Setup Docs or
  `gitlab` preflight, and verify the exact
  `git rev-parse origin/<default_branch>` SHA that will seed the branch.
- Create the source branch/worktree from that verified `origin/<default_branch>`
  SHA. Abort instead of branching if the SHA cannot be read, changes before
  creation, or the command would fall back to a local/stale default branch.
- For multi-issue work, repeat fetch plus default-branch SHA verification before
  every child worktree. Do not reuse an earlier fetch or cached default SHA
  across children.
- After a merge, local cleanup is ordered after default safety: fetch origin,
  fast-forward the local default in a clean checkout, then remove local
  worktrees or delete local source branches. When a squash/merge commit means
  the reviewed SHA is not the commit on default, an equivalent safety check is
  acceptable only when the MR's `merge_commit_sha` or `squash_commit_sha` is
  verified as an ancestor of the fast-forwarded local default. If neither check
  passes, retain the local worktree/branch and report cleanup pending.

## Parent loop

1. **Resolve issue(s).** Read the issue, comments, labels, linked MRs or parent design docs, and project rulebook. Confirm each issue carries the target repo's AFK-ready Triage Role label from `project_profile.label_profile_ref` or is otherwise approved for agent work. If multiple issues are in scope, prove the [Decoupling Contract](skill://start-build/docs/decoupling-contract.md) before parallel work; otherwise process issues serially in dependency order. Classify each target issue/MR as `trivial`, `moderate`, or `high-risk` per [Skill-only model-tier routing](#skill-only-model-tier-routing) before child launch, and keep that tier bound to the builder/reviewer route.
2. **Prepare isolated work.** Verify clean status, then follow [Fresh default and cleanup order](#fresh-default-and-cleanup-order): fetch origin immediately before each source branch/worktree, verify the exact `origin/<default_branch>` SHA, and create the source branch or isolated worktree from that verified SHA. The parent checkout remains coordinator-only during multi-issue runs.
3. **Launch the routed child builder.** Immediately before launching each builder, re-read the issue's assignee and state; if it changed since allocation or is already assigned to another active session, stop and ask rather than launching a builder that would race on the same issue. Consume the bound tier and launch the exact builder agent: `trivial` -> `mr-builder-sonnet-low`, `moderate` -> `mr-builder-opus48`, `high-risk` -> `mr-builder-opus48-high`. If the parent runtime exposes the `subagent` API, call `subagent({ action: "list" })` and verify that exact agent name is available; generic issue-implementation specialization discovery (for example `mr-builder`, `gitlab-builder`, or a project-scope `builder`/`worker` override) is compatibility guidance for manual direct selection outside this skill-only parent-loop enforcement surface, not a substitute route. Launch one builder per issue/worktree with only one target issue URL/IID, one worktree, the target branch, exact role/mode, explicit stop condition, expected handoff schema, forbidden actions, and the minimum evidence pointers needed for that issue; do not restate broad parent reasoning unless a specific risk requires narrow extra context. Never let two agents share a checkout, branch, temp DB, port, or uncommitted artifact directory. The builder still owns implementation, Draft MR creation, Review Packet / Reviewer Lift upkeep, targeted evidence, and final handoff.
4. **Parent spot-check / parent-owned gate.** Before review, validate the builder handoff and MR via `gitlab` snippets: MR URL/IID, `Closes #...`, source and target branch, pushed branch, current MR head SHA, builder `head_sha`, builder `reviewed_sha` or candidate SHA, shared `delivery` claim indexes when present, `delivery.handoff_contract` (`phase`, `expected_next_actor`, `expected_next_action`, `blocked`, `blocker_token`, `required_parent_decision`, `safe_to_continue_without_parent`, `changed_since_last_handoff`, and `evidence_ready_for_next_actor`; `blocking_question` only when specific/actionable), Reviewer Lift `Reviewed SHA`, pipeline SHA when exposed, changed paths, touched safety surfaces, decoupling proof, local gate result or canonical parent-owned ownership contract, open questions, approval authority/source, merge authority, and merge authority source. **AC-deliverable exists:** for each issue AC that names a produced evidence artifact (tabulated diff, recorded identification, note at a named location, or other deliverable at a specific path or comment), verify the artifact exists at that location; prior-work references and indirect validation do not satisfy it — reject and re-queue the builder if the named artifact is absent. Treat compact delivery fields as untrusted until verified from Tier 1/Tier 2 evidence, and escalate if the handoff is missing, stale, out of scope, or contradicts the issue/rulebook. If the handoff says `local_gate_owner: parent`, run [parent-owned-gate.md](parent-owned-gate.md) before ready-marking.
5. **Launch final review.** Launch the reviewer in parallel with CI as soon as the build handoff lands; see [Reviewer launch timing](#reviewer-launch-timing). Do not block-watch the pipeline to terminal-green before launching the reviewer — the approval/merge guards plus the default queued auto-merge finish already enforce exact-SHA CI, so pre-CI parallel launch is the default for every tier. This is parent-side launch sequencing only and does not replace or weaken the reviewer's own exact-SHA CI verification, fail-closed CI guard, or bounded CI wait. Then start the runtime's mandatory independent final reviewer for every tier: `mr-reviewer-opus48-xhigh` on Claude Code, or `mr-reviewer-gpt55-xhigh` on OMP. For `trivial` work on OMP, the parent may launch `mr-review-scout-gpt54-low` before final review, but scout output is non-gate, cannot satisfy independent review, and cannot approve/pass/fail/request changes; Claude Code has no `openai-codex/*` scout route. Immediately before launching the reviewer, re-resolve the reviewer route from the current runtime inventory: when the parent runtime exposes the `subagent` API, call `subagent({ action: "list" })` and confirm the exact routed reviewer name is present; when `agent_inventory` changed since batch start (for example, an earlier MR in this batch updated agent routes), this runtime re-resolution is required to avoid launching a stale route the merged work removed. Generic MR / code-review specialization discovery (for example `mr-reviewer`, `gitlab-reviewer`, or a project-scope `reviewer` override) is compatibility guidance for manual direct selection outside this skill-only parent-loop enforcement surface, not a substitute route. On OMP, use `mr-reviewer-opus48-xhigh` only as a provider-failure fallback after an explicit parent/operator decision token confirms the `mr-reviewer-gpt55-xhigh` route is unavailable; never describe or select it as a cost downgrade. Start a fresh reviewer session with only one bound MR URL, exact role/mode, explicit stop condition, expected handoff schema, forbidden actions, minimum evidence pointers (Reviewer Lift, Gate Receipt when present, project rulebook), and the instruction not to treat parent/builder reasoning as evidence. Add a run directory only as a local artifact pointer when needed, not as review reasoning. The reviewer still posts one GitLab Review Report for one reviewed SHA, then returns the parseable reviewer final handoff from `../../start-review/templates/reviewer-final-handoff.md` after any authorized action attempt. The GitLab Review Report remains the durable review record; the final handoff is a parsing aid. Approval follows the verified approval authority policy; merge actions remain limited by separate explicit merge authority and verifiable `Merge authority source` in the Review Packet, parent/human instruction, or project rulebook.
6. **Drive the decision loop.** On `pass` (with recorded approval action), run the SHA/CI guard before any finish action; the `pass` verdict is the review judgment only, and the approval action stays a separate recorded side effect. On `request-changes`, send the builder only the revision inputs that are still authoritative: MR URL, reviewed SHA, Review Report URL, finding IDs, required fix acceptance criteria, gate owner, and the exact expected handoff on return. Require fix commits, targeted evidence, a full local gate when substantive, a file-backed revision note, and updated Reviewer Lift before a fresh reviewer session reads the new SHA. On `reject`, stop and escalate. On `blocked`, record the blocker and escalate without finishing or spawning another reviewer for the same blocker. Wait on the child's completion notification rather than polling its status mid-run. On missing Review Report after the wait budget, check the reviewer run status/activity before replacement. Use the runtime's status/control/interruption mechanism when available; interrupt or replace only a run that is failed, stale, interrupted, or unreachable and record the reason. Do not start a second reviewer while the first run is still active. If status/control is unavailable or ambiguous, escalate instead of launching a duplicate reviewer. Keep the three-round review limit from the standalone gate.
7. **Enforce SHA and CI guards.** Before approval, merge, or auto-merge, re-read MR metadata and require the current MR SHA to equal the reviewed SHA. Treat CI as valid only when it is for that SHA. Red, canceled, skipped, missing, or stale CI blocks merge unless an authorized human records an explicit waiver. Pending CI may only be accepted under the CI-pending review policy and protected merge checks.
8. **Finish by authority.** For `approval-only` or `human release`, stop after reporting reviewed SHA, CI, and blockers. For `reviewer may merge` or `queue auto-merge`, only an authorized reviewer or parent may approve, merge, or queue with the reviewed SHA; a child builder still must not approve or merge. **The default finish is to approve SHA-bound and queue auto-merge** ([start-review Default finish: queued auto-merge](../../start-review/REVIEW-FLOW.md#default-finish-queued-auto-merge)) when the reviewed-SHA pipeline is `pending`/`running`/`success`, so GitLab completes the merge the instant CI passes and the parent does not hold a foreground/background CI watcher; direct merge is for the already-exact-SHA-green (or human-waived) case. The fail-closed guard is unchanged: a `failed`/`canceled` (or red/missing/stale) reviewed-SHA pipeline blocks finish — do not queue or merge it. When merge authority is already in hand, the approving reviewer (or the parent) performs the SHA-guarded finish in the existing session — do not spawn a dedicated finisher agent for a single merge or queue command; spin up a separate authorized finisher only when authority arrives after the review session has ended. After merge or queueing, follow [Fresh default and cleanup order](#fresh-default-and-cleanup-order): fetch the target branch, verify issue closure or pending closure, remove clean worktrees, and delete source branches only when project policy and default-branch safety allow.
9. **Verify after merge.** Keep post-merge verification separate from review and finish authority. The parent or verifier follows [Post-merge verifier recipe](post-merge-verifier.md), preferably using `gitlab/scripts/gitlab-post-merge-snapshot.sh`, to emit a read-only `post_merge_snapshot.kind=post-merge-snapshot` block for merged/default-branch state, explicit reviewed/merge/squash containment, linked issue closure or `issue_closure_pending`, source-branch cleanup or retention state, validation result/not-run reason, and pending items.
10. **Archive local artifacts.** Keep local run artifacts redacted and untracked. Local handoff files are convenience artifacts only. Durable handoff stays in GitLab MR descriptions and comments, using file-backed comments for multiline updates.

## Reviewer launch timing

Step 5 starts the final reviewer in parallel with CI as soon as the build handoff lands. This is parent-side launch sequencing only: it never substitutes for or relaxes the reviewer's own exact-SHA CI verification, its fail-closed CI guard, or its bounded CI wait, which all stay exactly as defined in `start-review`. The reviewer still independently re-derives CI evidence for the SHA it reviews; the parent does not hand its CI read to the reviewer as fact.

- **Parallel launch is the default for every tier** (`trivial`, `moderate`, `high-risk`). The reviewer starts while CI runs, since review work typically overlaps and covers CI latency. The parent does **not** block-watch the candidate SHA's pipeline to terminal-green before launching the reviewer. The retired prior rule made `trivial`-tier launches wait for terminal-green CI first; that block-wait is removed because the approval/merge guards plus the default queued auto-merge finish ([start-review Default finish: queued auto-merge](../../start-review/REVIEW-FLOW.md#default-finish-queued-auto-merge)) already require pass-eligible exact-SHA CI before any merge completes. Waiting first only delayed the agent without strengthening any gate.
- **Fail-closed on red/canceled CI is unchanged.** If the candidate SHA's pipeline is already `failed`/`canceled`, do not finish on it: the reviewer's CI decision table blocks approval/merge, and the parent routes the MR back to the builder or escalates rather than queueing or merging. Parallel launch does not weaken this guard; it only avoids a foreground block-watch before the reviewer even starts.

In every tier the reviewer's bounded CI wait and CI-pending review policy are unchanged: if the reviewer reaches a SHA whose CI is not yet pass-eligible, it applies its own `start-review` CI-pending/fail-closed policy. Parallel launch here only changes the parent's launch timing, not any reviewer guard.

## Minimal reviewer launch prompt

When the parent starts a fresh reviewer, pass only the review target and bounded
routing/evidence instructions:

```text
Review MR: <MR web URL>
Agent: mr-reviewer-opus48-xhigh on Claude Code, or mr-reviewer-gpt55-xhigh on OMP
Route-resolved-at-launch: <confirmed via subagent({ action: "list" }) from current runtime inventory, or manual direct selection>
Mode: mr-reviewer
Stop condition: post one Review Report and return the final handoff after any authorized action attempt.
Expected handoff schema: start-review/templates/reviewer-final-handoff.md (`delivery.handoff_contract` included and current).
Forbidden actions: do not treat parent/builder reasoning as evidence; do not approve when approval authority is restricted or unverified; do not merge, queue auto-merge, or close without separate verified merge authority/source plus fresh SHA/CI guards.
Evidence pointers: Reviewer Lift block in the MR description, Gate Receipt comment when present, and project rulebook path.
Fallback: on OMP, mr-reviewer-opus48-xhigh only with an explicit parent/operator provider-failure decision token; never a cost downgrade. Claude Code uses mr-reviewer-opus48-xhigh as its primary final reviewer, not a fallback.
Scout note: mr-review-scout-gpt54-low is the OMP-only optional trivial pre-review scout; it is non-gate and cannot satisfy independent review. Claude Code has no openai-codex/* scout route.
```

Do not include parent/builder planning details, summaries, hypotheses, prior conversation, or hidden reasoning in the launch prompt. If a coordination constraint must be passed, state it as a claim/source pointer for independent verification.

## Minimal child-builder launch prompt

When the parent starts a child builder, pass only the issue-specific routing facts:

```text
Build issue: <issue URL>
Delivery tier: <trivial | moderate | high-risk>
Agent: <mr-builder-sonnet-low | mr-builder-opus48 | mr-builder-opus48-high>
Worktree: <absolute worktree path>
Target branch: <default branch>
Mode: child mr-builder
Gate owner (gate-ownership selection): <builder | parent>   # builder = builder-owned gate; parent = parent-owned gate; default when this line is omitted is builder (builder-owned)
Stop condition: return the final handoff after updating the Draft/ready MR for this issue.
Expected handoff schema: start-build/templates/builder-final-handoff.md (`delivery.handoff_contract` included and current).
Forbidden actions: do not spawn reviewers; do not approve, merge, queue auto-merge, or claim parent-owned gate pass/fail; when Gate owner is parent: do not mark the MR ready or perform any draft→ready transition — leave it Draft for the parent's Gate Receipt and ready transition; when Gate owner is builder: run the gate and mark ready per standard flow.
Evidence pointers: project rulebook path, repo Check Gate path, MR URL if it already exists, and any narrowly relevant issue-linked docs/tests.
```

The `Gate owner` line is the explicit gate-ownership selection. Set it once per
batch so every identically-shaped issue routes to one gate mode, rather than
letting each child infer the mode from finish-authority prose. The child reads
this field and must not infer gate ownership from "finish authority" or other
merge/finish-authority wording; those wordings govern who may finish, not who
runs the local gate. When the line is omitted, the documented default is
**builder (builder-owned)**: the child runs the local gate and marks ready per the
standard flow. `parent` selects parent-owned gate mode, whose per-mode semantics
(ownership contract, Gate Receipt, ready transition) remain owned by
[parent-owned-gate.md](parent-owned-gate.md); this field only names the
selection.

Do not include broad parent reasoning, cross-issue summaries, hidden hypotheses,
or unrelated backlog context in the builder prompt. If a specific risk requires
extra context, pass only that risk as a claim/source pointer the builder can
verify.

## Minimal revision prompt

When the parent routes request-changes back to a builder, pass only the
review-bound revision facts:

```text
Revise MR: <MR web URL>
Reviewed SHA: <reviewed SHA from the Review Report>
Review Report: <Review Report comment URL>
Finding IDs: <MF-N / SF-N / C-N IDs to address>
Required fix acceptance criteria: <one short bullet per finding>
Gate owner: <builder or parent-owned gate mode>
Expected handoff on return: <updated builder-final handoff / Reviewer Lift state expected next>
```

Add extra context only when a specific finding cannot be understood from the MR,
Review Report, linked issue, and cited files alone. Human/product/security
choices stay blocked routing (`human-decision-needed`) until the decision source
exists; do not paraphrase the missing decision as builder work.
