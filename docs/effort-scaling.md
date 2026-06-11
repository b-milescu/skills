# Effort Scaling

Match the ceremony of a change to its **risk × blast radius**. Spend tokens, agents, and review depth where a mistake is costly; take the cheap path where it is not. This governs *how much* discovery, packet detail, design exploration, and verification a change earns — it never lowers a safety gate.

## Tiers

| Change shape | Discovery | Packet | Design phase | Verification |
| --- | --- | --- | --- | --- |
| **Trivial** — docs/prose, typo, lint, mechanical or config, single-line | issue + rulebook only | compact packet | none — single pass | local gate + one focused check |
| **Moderate** — bounded behavior in one unit, small feature or bugfix | affected surfaces + direct callers/tests | full packet | none — single pass | local gate + one independent review |
| **High-risk** — safety/runtime/operator/migration/security, cross-cutting, or ambiguous | full discovery budget | full packet | analyst/refuter panel only when the solution space is wide | independent review + adversarial verification |

**Design phase = the analyst/refuter fan-out** (parallel agents exploring approaches or adversarially refuting a proposal). It is *not* keyed to how many files change: a one-line edit with an obvious form is trivial even when it touches a load-bearing file. Run a panel only at the high-risk tier *and* only when the solution space is genuinely wide (multiple viable approaches, unclear tradeoffs). For trivial/moderate work, reason it through in a single pass; a panel on a settled one-line change is the most common discretionary waste.

**Tier also sets reviewer-launch timing, not just depth.** When a parent orchestrator launches the final reviewer, *when* it launches is tier-dependent: the `trivial` tier waits for exact-SHA terminal-green CI before launch, while `moderate`/`high-risk` launch in parallel with CI. See the canonical rule in [parent-orchestrator §CI-aware reviewer launch](skill://start-build/reference/parent-orchestrator.md#ci-aware-reviewer-launch); it is parent-side sequencing only and does not change the mandatory review gate or any reviewer CI guard below.

## Hard floors (never scaled away)

- The **mandatory independent review gate** applies to every behavior-touching change regardless of tier; only discovery, packet, design, and verification *depth* scale.
- TDD for behavior-touching work, the safety non-negotiables, the SHA/CI/authority guards, and the builder/context-firewall finish boundaries hold at every tier.
- Scaling down is a claim, not a default: record the chosen tier and why in the packet so a reviewer can challenge it.

## Token economy

- Wait on completion events; do not poll or re-read child agents mid-run (see `../start-build/reference/timeout-handling.md`).
- When merge authority is granted up front, the approving reviewer finishes in-session — no separate finisher agent for a single merge command.
- Do not fan out multiple analysis or verification agents for a change a single pass covers; reserve fan-out for wide solution spaces and high-risk verification (see the design-phase note above).
- Recon shared facts once, then reuse. When several builder-side subagents need the same inputs (invariant tests, rulebook tokens, file shapes), gather them once in the coordinating context and pass the digest into each prompt rather than letting every agent re-read the same files. This does **not** apply to the mandatory review gate: independent reviewers re-derive evidence by design and must not be handed builder-gathered conclusions as fact.
- Verify mutations from their own authoritative read-back, not from a prior step's reported success; treat unconfirmed success as not-done.
