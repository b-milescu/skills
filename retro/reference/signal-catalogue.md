# Retro signal catalogue

Friction signals worth scanning for after a build/review/delivery run, with where to look and the finding category each usually maps to. Walk every row during [SKILL.md](../SKILL.md) flow step 3; the catalogue is a checklist, not a cap — record any evidence-backed friction even when no row matches.

## Category definitions

- **flow** — ordering, handoff, or routing problems between roles (builder / reviewer / parent / verifier): steps that ran in the wrong order, handoffs that bounced, missing or skipped stages, cleanup that never ran.
- **process** — ceremony/effort miscalibration and policy friction: packets heavier than the tier warrants, rounds spent on avoidable defects, reports produced but never consumed.
- **context** — context loading and size problems: the same files read repeatedly across agents, canonical bodies restated in prompts, required reads that never influenced a decision, launch prompts beyond the minimal shape.
- **taxonomy** — vocabulary gaps and collisions: events forced into `other`, metrics without definitions, enum values missing, the same concept under several names across docs.
- **tooling** — transport/helper/runtime defects and repeated workarounds in the target's confirmed integration, local git or advisory CI.
- **docs-drift** — canonical docs disagreeing with each other or with observed behavior; duplicated inventories that drifted apart.

## Signals

| Signal | Where to look | Usual category |
|---|---|---|
| Repeated workaround — the same error worked around twice or more (within the session, or vs memory/issue history) | conversation, memory-plugin observations if present, `/forge` helper output | tooling |
| MCP call failures, contract-inconsistent output, or documented unavailability of a required tool | scoped session calls/outputs/unavailability; implicated local evidence only under SKILL.md's session-first contract | tooling |
| Review rounds > 1 on any change request — classify the root cause: brief defect, builder defect, evidence gap, or reviewer scope creep | Review Reports, revision packets, Review Gate Summary | process |
| Blocker tokens fired (`missing-authority`, `changed-head-sha`, `merge-conflict`, `partial-review`, ...) — was the blocker avoidable upstream? | verified durable Review Reports / Review Packets, supported compact `delivery.handoff_contract` indexes, action-result notes located by reviewer finals | flow |
| `other` used in `action_blocker`, `blocker_token`, or `not_run_reason` — the enum lacked a real value | delivery-loop batch report / Retro Report §Batch metrics, using [Metrics](skill://issue-delivery-loop/SKILL.md#metrics) for evidence sources and counting | taxonomy |
| Timeout / stale / interrupted reviewer or builder rounds | Review Gate Summary, parent loop records | flow |
| Leftover local state after the run — worktrees, `refs/tmp/review/*` temp refs, undeleted source branches, dirty checkouts | `git worktree list`, `git for-each-ref refs/tmp`, `git branch`, `git status --porcelain` | flow |
| Check Gate failing on the default branch after merges | gate command on a fresh default-branch checkout | process |
| Ceremony/tier mismatch — trivial work carrying a full packet or agent fan-out, or high-risk work routed through the trivial path | issue tier vs the packets/agents actually used; Effort Scaling tiers | process |
| Handoff defects — missing or stale Reviewer Lift fields, placeholder `OQ-N`, generated-copy drift against the canonical schema | change request descriptions, schema regression tests, Review Reports | docs-drift |
| Context bloat — repeated reads of the same sources across agents, canon restated instead of pointed to, oversized launch prompts | builder/reviewer launch prompts, context-expansion rows, token warnings | context |
| Required reads that never influenced a decision, or Tier 3 reads that did | Build Plan Packet and Review Context Capsule context rows | context |
| Workflow state recorded only in prose because no live label exists (needs-info, human-decision, revision, unblock) | issue/change request comments vs the target repo's live label inventory | taxonomy |
| Metrics reported but undefined or unmeasurable (for example, what counts as a "brief defect") | batch metrics vs the operating contract that names them | taxonomy |
| Two canonical sources giving different vocabulary or rules for the same decision point | the docs actually cited during the run | docs-drift |

## Recurrence check

Before classifying a `tooling` or `flow` finding as `adopt`, check whether it already recurred: search the active memory skill/MCP (when available) and recent issues on the bound tracker for the same error signature or workaround. A first occurrence with a clean recovery may stay `monitor`; a second occurrence is a pattern that earns a fix proposal naming the evidenced Owner when the cause supports a bounded fix. Recurrence alone does not establish a cause.

## Ownership mapping hints

**Attribution needs causal evidence.** Separate observed friction from established root cause. Schema-valid input, repeated retries, and successful CLI recovery do not independently establish a server defect; unresolved cause stays `monitor`, with Owner `unknown` when not evidenced. Caller misuse does not automatically justify changing skill instructions: establish that incorrect instructions caused the misuse before routing a proposal there.

Route proposals to the implementation, configuration, documentation, or skill that owns the cause, not where the symptom appeared. Record the repository and component/file locator when evidenced:

- MCP server-contract violation causally tied to responsible implementation → that implementation repository/component, not a skill workaround.
- Configuration or upstream-service cause → the evidenced configuration owner or upstream repository/component; if evidence cannot resolve ownership, retain `unknown`.
- Incorrect skill instructions causing caller misuse → the owning instructions, not the server.
- Native integration tools/recipes/fallback guidance → the invoked target's selected `provider.reference` owner when causally evidenced; common binding/guard contracts → `forge`.
- Build behavior, TDD/safety policy, builder handoffs → `start-build` (mode reference docs own mode detail).
- Review behavior, verdict/CI/OQ policy, reviewer handoffs → `start-review`.
- Batch coordination, tier routing, batch metrics → `issue-delivery-loop`.
- Target-repo policy (labels, Check Gate, branch naming, workflows) → that repo's confirmed Agent Setup Doc paths, never installed aliases/defaults.
- Shared contracts (effort scaling, decoupling) → the shared docs both flows point at.
