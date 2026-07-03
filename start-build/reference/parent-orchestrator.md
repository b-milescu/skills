# Parent-orchestrator recipe

Detailed parent/coordinator flow for child `mr-builder` and `mr-reviewer` GitLab issue-to-MR loops. This file is the canonical owner of the parent-orchestrator recipe; [SKILL.md](../SKILL.md) routes here from the mode matrix. Project rulebooks and `project_profile` hooks may specialize labels, local gates, branch naming, CI jobs, domain docs, release/deploy policy, manual validation, auxiliary indexes, merge authority defaults, merge authority source requirements, run artifact paths, and post-merge checks, but must not weaken the safety invariants in this flow.

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

## Skill-only tier routing

This routing is enforced only for flows launched through the parent loop. Manual direct agent selection outside enforcement surface; selected route frontmatter owns model pins, provider pins, and effort pins. The parent consumes delivery tier classified by `skill://issue-delivery-loop/SKILL.md`, classifies with the same criteria when called directly, and resolves route basenames only at the child/reviewer launch seam in the current runtime dialect directory.

- `trivial` requires all criteria to be true: docs/prose/templates/labels/inventory/checklist or other mechanical no-runtime work; no runtime behavior; no security/auth/permissions/billing; no schema/migration/persistence; no deploy/runtime/CI semantic change; no concurrency/state-machine/locking impact; no broad architecture/cross-file coupling; no broad multi-file or shared-harness test refactor; clear acceptance criteria.
- `high-risk` applies when any trigger is present: auth/security/crypto/secrets; migrations/schema/data-loss; deploy/runtime/infra/CI semantics; concurrency/locking/state machines/queues; billing/permissions/access control; large diff (`>=20` files or `>=1000` diff lines); unclear acceptance criteria.
- `moderate` is the default when work is neither `trivial` nor `high-risk`.

Test surface alone does not lower tier: route by blast radius, not by runtime-vs-test surface. broad test-only refactor — many touched test files (objective signal: `>=10` test files) or shared test-harness / cross-file test-coupling change — **not** `trivial` even though test-only runs no runtime code; route it at least `moderate` so large semantic test refactor takes higher-effort build/review path instead bouncing through avoidable review rounds. (A broad test refactor also trips `high-risk` trigger above — example `>=20` touched files — still routes `high-risk`.) rule only refines tier classification; canonical table below names shared model-free route basenames.

Route exact shared model-free route basenames by tier. The basename resolves inside the current runtime dialect directory: Claude Code loads `agents/claude/<route>.md`; OMP loads `agents/omp/<route>.md`. Model pins live in frontmatter; provider effort pins live too, never in route name. Route names are launch basenames, distinct from role/mode labels `child mr-builder` and `mr-reviewer`:

| Tier | Builder route | Final-reviewer route |
| --- | --- | --- |
| `trivial` | `mr-builder-trivial` | `mr-reviewer-final` |
| `moderate` | `mr-builder-moderate` | `mr-reviewer-final` |
| `high-risk` | `mr-builder-high-risk` | `mr-reviewer-final` |

The mandatory independent final reviewer route is `mr-reviewer-final` for every tier. There is no review scout or generic fallback builder/reviewer: when exact routed agent file unavailable in current dialect directory, stop with a route-unavailable blocker and explicit parent/operator decision rather than selecting a substitute route; never select a shim, old filename, cross-runtime route, lower-effort substitute, or cost downgrade.

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
- After merge, local cleanup stays ordered around default-branch safety: fetch origin, fast-forward local default in a clean checkout, then remove clean local worktrees and delete local source branches.
- Remote source-branch cleanup remains guarded. First confirm the real remote source branch is already gone (`git ls-remote origin <source_branch>` returns nothing) or delete it only after the merged reviewed SHA is contained by the fast-forwarded default branch. When squash/merge commit means the reviewed SHA is not itself on default, the equivalent safety check is that the MR's `merge_commit_sha` or `squash_commit_sha` is a verified ancestor of the fast-forwarded local default. If neither check passes, retain the local worktree/branch and report `cleanup_pending`.
- After the real remote branch deletion/absence checks pass, run the `git remote prune --dry-run origin` equivalent stale-ref check. Cleanup is complete only when that stale-ref result is empty. If stale local remote-tracking refs remain, report `cleanup_pending` with the stale refs listed instead of claiming branch cleanup complete.

## Parent-managed finish ownership

`Finish owner: parent` is the literal parent-managed dev-flow contract. In parent-orchestrated child-builder plus final-reviewer mode, reviewers post only Review Report verdict/evidence. They do not approve, merge, or queue auto-merge in that mode; parent/authorized finisher performs approval, direct merge, or auto-merge queue after re-reading current MR metadata and passing fresh MR SHA, CI, authority/source, identity, and GitLab Mutation Guard checks.

## Parent loop

1. **Resolve issue(s).** Read issue, comments, labels, linked MRs parent design docs, project rulebook. Confirm each issue carries target repo's AFK-ready Triage Role label `project_profile.label_profile_ref` otherwise approved agent work. If multiple issues in scope, prove [Decoupling Contract](skill://start-build/docs/decoupling-contract.md) before parallel work; otherwise process issues serially in dependency order. Classify target issue/MR `trivial`, `moderate`, or `high-risk` per [Skill-only tier routing](#skill-only-tier-routing) before child launch, keep tier-bound builder/reviewer route basenames.
2. **Prepare isolated work.** Verify clean status, then follow [Fresh default and cleanup order](#fresh-default-and-cleanup-order): fetch origin immediately before each source branch/worktree, verify the exact `origin/<default_branch>` SHA, and create the source branch or isolated worktree from that verified SHA. The parent checkout remains coordinator-only during multi-issue runs.
3. **Launch routed child builder.** Immediately before launching builder, re-read issue's assignee state; if changed since allocation already assigned another active session, stop and ask rather than launching builder that would race on the same issue. Consume the bound tier and launch the exact shared builder route basename from the canonical table in the current dialect directory (`agents/claude/<route>.md` or `agents/omp/<route>.md`): `trivial` -> `mr-builder-trivial`, `moderate` -> `mr-builder-moderate`, `high-risk` -> `mr-builder-high-risk`. If parent runtime exposes `subagent` API, call `subagent({ action: "list" })` and verify the exact route is available; generic issue-implementation specialists, aliases, shims, old filenames, and cross-runtime substitutes are not valid. Missing route is a route-unavailable blocker for parent/operator decision.
   Discovery guidance: `issue-implementation specialization` and `MR / code-review specialization` labels describe why the routed agents exist; they are never substitute route names.
4. **Parent spot-check / parent-owned gate.** Before review, validate the builder handoff MR via `gitlab` snippets. Confirm each item:
   - MR URL/IID
   - `Closes #...`
   - source target branch
   - pushed branch
   - current MR head SHA
   - builder `head_sha`
   - builder `reviewed_sha` or candidate SHA
   - shared `delivery` claim indexes present
   - `delivery.handoff_contract` (`phase`, `expected_next_actor`, `expected_next_action`, `blocked`, `blocker_token`, `required_parent_decision`, `safe_to_continue_without_parent`, `changed_since_last_handoff`, `evidence_ready_for_next_actor`; `blocking_question` only when specific/actionable)
   - Reviewer Lift `Reviewed SHA`
   - pipeline SHA when exposed
   - changed paths
   - touched safety surfaces
   - decoupling proof
   - local gate result or canonical parent-owned/not-run contract
   - approval authority/source
   - merge authority/source

   If child returned early because of a runtime/tool/budget notice, do not relabel issue scope blocked or treat notice as a human stop instruction: resume same child/worktree when runtime recovered and checkout still safe, otherwise record a runtime/tool blocker or relaunch exact same assigned scope from same worktree state without changing issue classification.
5. **Launch final review.** Launch reviewer in parallel with CI once build handoff lands; see [Reviewer launch timing](#reviewer-launch-timing). Do not block-watch pipeline terminal-green before launching reviewer — approval/merge guards plus default queued auto-merge finish already enforce exact-SHA CI, so pre-CI parallel launch default every tier. parent-side launch sequencing only does not replace or weaken reviewer's own exact-SHA CI verification, fail-closed CI guard, or bounded CI wait. Start runtime's mandatory independent final reviewer route tier: `mr-reviewer-final`, resolved current dialect directory. Immediately before launching reviewer, re-resolve MR metadata and verify current MR head SHA still equals candidate SHA builder handoff named.
6. **Drive decision loop.** On `pass`, treat Review Report verdict/evidence as review judgment only. In `Finish owner: parent` mode, reviewer action fields must be `Approval action: not-approved`, `Finish action: none`, `Action blocker: none`, and `Next action: finish-by-authorized-actor`; parent then runs fresh SHA/CI/authority/identity/mutation guards before any approval, direct merge, or auto-merge queue action. On `request-changes`, send builder only revision inputs still authoritative: MR URL, reviewed SHA, Review Report URL, finding IDs, required fix acceptance criteria, gate owner, exact expected handoff on return. Require fix commits, targeted evidence, full local gate when substantive, file-backed revision response. On `reject`, stop and escalate. On `blocked`, record blocker and escalate without finishing or spawning another reviewer for same blocker.
7. **Enforce SHA and CI guards.** Before approval, merge, or auto-merge, re-read MR metadata and require the current MR SHA to equal the reviewed SHA. Treat CI as valid only when it is for that SHA. Red, canceled, skipped, missing, or stale CI blocks merge unless an authorized human records an explicit waiver. Pending CI may only be accepted under the CI-pending review policy and protected merge checks.
8. **Finish authority.** `Finish owner: parent` distinct merge authority: merge authority says finish action allowed, while finish owner says who performs it in parent-managed mode. For `approval-only` or `human release`, stop reporting reviewed SHA, CI, blockers. For `reviewer may merge` or `queue auto-merge`, only parent/authorized parent/human finisher performs approval, merge, queue after independent final-reviewer pass plus durable Review Report, fresh MR SHA guard, exact-SHA CI guard, verified authority source, caller identity/context guard, GitLab Mutation Guard (including Safe GitLab Text for body mutations), one mutation at a time, and post-mutation verification. **The default finish approve SHA-bound queue auto-merge** ([start-review Default finish: queued auto-merge](../../start-review/REVIEW-FLOW.md#default-finish-queued-auto-merge)) on reviewed-SHA pipeline `pending`/`running`/`success`, so GitLab completes merge soon CI passes parent does not hold foreground/background CI watcher. Bind the finish action to the granted authority, not to CI state: under `queue auto-merge` authority the finish action is always `queue-auto-merge`, even when the exact-SHA pipeline is already green — GitLab then completes the merge immediately, so a separate direct-merge action is neither needed nor permitted. Direct merge is reserved for `reviewer may merge` or higher / human authority. fail-closed guard remains: failed, canceled, skipped, missing, stale CI cannot approve/merge/queue without human waiver.
9. **Verify after merge.** Keep post-merge verification separate from review and finish authority. The parent or verifier follows [Post-merge verifier recipe](post-merge-verifier.md), preferably using `get_post_merge_snapshot`, to emit a read-only `post_merge_snapshot.kind=post-merge-snapshot` block for merged/default-branch state, explicit reviewed/merge/squash containment, linked issue closure or `issue_closure_pending`, source-branch cleanup or retention state, validation result/not-run reason, and pending items.
10. **Archive local artifacts.** Keep local run artifacts redacted and untracked. Local handoff files are convenience artifacts only. Durable handoff stays in GitLab MR descriptions and comments, using file-backed comments for multiline updates.

## Reviewer launch timing

Step 5 starts the final reviewer in parallel with CI as soon as the build handoff lands. This is parent-side launch sequencing only: it never substitutes for or relaxes the reviewer's own exact-SHA CI verification, its fail-closed CI guard, or its bounded CI wait, which all stay exactly as defined in `start-review`. The reviewer still independently re-derives CI evidence for the SHA it reviews; the parent does not hand its CI read to the reviewer as fact.

- **Parallel launch is the default for every tier** (`trivial`, `moderate`, `high-risk`). The reviewer starts while CI runs, since review work typically overlaps and covers CI latency. The parent does **not** block-watch the candidate SHA's pipeline to terminal-green before launching the reviewer. The retired prior rule made `trivial`-tier launches wait for terminal-green CI first; that block-wait is removed because the approval/merge guards plus the default queued auto-merge finish ([start-review Default finish: queued auto-merge](../../start-review/REVIEW-FLOW.md#default-finish-queued-auto-merge)) already require pass-eligible exact-SHA CI before any merge completes. Waiting first only delayed the agent without strengthening any gate.
- **Fail-closed on red/canceled CI is unchanged.** If the candidate SHA's pipeline is already `failed`/`canceled`, do not finish on it: the reviewer's CI decision table blocks approval/merge, and the parent routes the MR back to the builder or escalates rather than queueing or merging. Parallel launch does not weaken this guard; it only avoids a foreground block-watch before the reviewer even starts.

In every tier the reviewer's bounded CI wait and CI-pending review policy are unchanged: if the reviewer reaches a SHA whose CI is not yet pass-eligible, it applies its own `start-review` CI-pending/fail-closed policy. Parallel launch here only changes the parent's launch timing, not any reviewer guard.

- Reviewer replacement is fail-closed: check the reviewer run status/activity before replacement. Do not start a second reviewer while the first run is still active; Do not start second reviewer while first run still active. no fixed wall-clock value alone authorizes replacement. Replace only after observed reviewer status/activity shows the first attempt failed, stale, interrupted, or unreachable, and otherwise escalate instead of launching a duplicate reviewer.

## Minimal reviewer launch prompt

The minimal reviewer launch prompt keeps only the MR URL, Reviewer Lift pointer,
Project rulebook path, and a do-not-treat parent/builder reasoning as evidence
instruction.

When the parent starts a fresh reviewer, pass only the review target and bounded
routing/evidence instructions:

```text
Review MR: <MR web URL>
Agent: mr-reviewer-final (resolve basename in current dialect directory: agents/claude/mr-reviewer-final.md or agents/omp/mr-reviewer-final.md)
Route-resolved-at-launch: <confirmed via subagent({ action: "list" }) from current runtime inventory, or manual direct selection>
Mode: mr-reviewer
Skills: invoke start-review and gitlab via the Skill tool before any review step. Do not satisfy this by Reading a reference file (e.g. REVIEW-FLOW.md) — a raw Read enters mid-policy and skips the SKILL.md entry procedure (preflight, project-binding, Context Firewall, SHA/CI guards). The Skill invocation is the load; reference files are read only after.
Stop condition: post one Review Report and return the final handoff after any authorized action attempt.
expected handoff schema: start-review/templates/reviewer-final-handoff.md (`delivery.handoff_contract` included and current).
Finish owner: parent
Forbidden actions: do not treat parent/builder reasoning as evidence; in this parent-managed mode do not approve, merge, queue auto-merge, or close even when merge authority verifies; post Review Report verdict/evidence and route `Next action: finish-by-authorized-actor` to parent/authorized finisher.
minimum evidence pointers: Reviewer Lift block in MR description, Gate Receipt comment present, project rulebook path.
Merge authority grant (only when granted): <orchestrator/parent merge-authority grant relayed for this MR — the granted value plus its source provenance (the human/parent instruction that granted it). An accepted parent task prompt (parent-explicit) source the reviewer verifies through gitlab/reference/authority-verification.md before finishing. Omit this line when no merge authority was granted.>
```

Do not include parent/builder planning details, summaries, hypotheses, prior conversation, or hidden reasoning in the launch prompt. Do not name the skill's internal reference files (for example `REVIEW-FLOW.md` or `child-builder.md`) in the launch prompt; name the skill and instruct Skill-tool invocation, so the subagent enters through the SKILL.md entry procedure rather than raw-Reading a mid-policy file. If a coordination constraint must be passed, state it as a claim/source pointer for independent verification.

The reviewer posts a durable GitLab Review Report and returns `reviewer-final-handoff.md` as a parseable parent-orchestrator parsing aid; the durable GitLab Review Report stays the canonical record, and the returned handoff is a parsing aid only.

A merge-authority **grant** the human/parent gave the orchestrator is the one accepted exception, and it is not builder reasoning: relay it as an explicit orchestrator/parent merge-authority grant with its source provenance — an accepted `parent task prompt` (`parent-explicit`) source per [authority-verification.md](../../gitlab/reference/authority-verification.md) — so the reviewer has a verifiable merge-authority source and can finish in the same session instead of blocking as `missing-authority`. The reviewer still verifies the relayed source before any finish action and never treats it as evidence about the code. Standalone `/start-build` mode relays the same grant through [standalone-gate.md §Reviewer launch protocol](standalone-gate.md#reviewer-launch-protocol).

## Minimal child-builder launch prompt

When the parent starts a child builder, pass only the issue-specific routing facts:

```text
Build issue: <issue URL>
Delivery tier: <trivial | moderate | high-risk>
Agent: <trivial: mr-builder-trivial | moderate: mr-builder-moderate | high-risk: mr-builder-high-risk> (resolve basename in current dialect directory: agents/claude/<route>.md or agents/omp/<route>.md)
Worktree: <absolute worktree path>
Target branch: <default branch>
Mode: child mr-builder
Skills: invoke start-build and gitlab via the Skill tool before any build step. Do not satisfy this by Reading a reference file (e.g. child-builder.md) — a raw Read enters mid-policy and skips the SKILL.md entry procedure (mode matrix, gate-ownership read, TDD/safety flow). The Skill invocation is the load; reference files are read only after.
Gate owner (gate-ownership selection): <builder | parent>   # builder = builder-owned gate; parent = parent-owned gate; default when this line is omitted is builder (builder-owned)
Stop condition: return final handoff after updating Draft/ready MR issue. Runtime budget/token/runtime notices are not scope changes and do not override this stop condition; only explicit human stop instructions or real issue/workflow blockers do.
expected handoff schema: start-build/templates/builder-final-handoff.md (`delivery.handoff_contract` included and current).
Forbidden actions: do not spawn reviewers; do not approve, merge, queue auto-merge, or claim parent-owned gate pass/fail; when Gate owner is parent: do not mark the MR ready or perform any draft→ready transition — leave it Draft for the parent's Gate Receipt and ready transition; when Gate owner is builder: run the gate and mark ready per standard flow.
minimum evidence pointers: project rulebook path, repo Check Gate path, MR URL if already exists, any narrowly relevant issue-linked docs/tests.
Reference staleness: issue line numbers/counts are measured at the brief's baseline commit and may be stale after intervening merges — re-locate every referenced block by content (function/heading name), not line number, and note any reconciliations in the MR description.
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
