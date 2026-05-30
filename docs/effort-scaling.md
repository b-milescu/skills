# Effort Scaling

Match the ceremony of a change to its **risk × blast radius**. Spend tokens, agents, and review depth where a mistake is costly; take the cheap path where it is not. This governs *how much* discovery, packet detail, design exploration, and verification a change earns — it never lowers a safety gate.

## Tiers

| Change shape | Discovery | Packet | Design phase | Verification |
| --- | --- | --- | --- | --- |
| **Trivial** — docs/prose, typo, lint, mechanical or config, single-line | issue + rulebook only | compact packet | none | local gate + one focused check |
| **Moderate** — bounded behavior in one unit, small feature or bugfix | affected surfaces + direct callers/tests | full packet | none–light | local gate + one independent review |
| **High-risk** — safety/runtime/operator/migration/security, cross-cutting, or ambiguous | full discovery budget | full packet | options when the solution space is wide | independent review + adversarial verification |

## Hard floors (never scaled away)

- The **mandatory independent review gate** applies to every behavior-touching change regardless of tier; only discovery, packet, design, and verification *depth* scale.
- TDD for behavior-touching work, the safety non-negotiables, the SHA/CI/authority guards, and the no-self-merge rule hold at every tier.
- Scaling down is a claim, not a default: record the chosen tier and why in the packet so a reviewer can challenge it.

## Token economy

- Wait on completion events; do not poll or re-read child agents mid-run (see `../start-build/reference/timeout-handling.md`).
- When merge authority is granted up front, the approving reviewer finishes in-session — no separate finisher agent for a single merge command.
- Do not fan out multiple analysis or verification agents for a change a single pass covers; reserve fan-out for wide solution spaces and high-risk verification.
- Verify mutations from their own authoritative read-back, not from a prior step's reported success; treat unconfirmed success as not-done.
