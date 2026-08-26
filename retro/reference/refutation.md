# Refutation pass

The refuter is the adversary of the draft Retro Report. It runs once, between drafting ([SKILL.md](../SKILL.md) flow step 5) and presenting (step 7), in a fresh context holding the draft and the evidence locators but not the collection reasoning. Its output is one verdict per `RF-N`, applied to the report before any human sees it.

Target the finding, not the drafter. A finding earns its place by surviving the strongest argument against it.

## Attack surface

Walk every row against every `RF-N`. Re-open at least one cited source per finding: judge the evidence, not the claim about it.

| Attack | The finding survives when | Verdict when it fails |
| --- | --- | --- |
| **Source check** — open the locator. Does it say what the claim says? | the cited excerpt backs the claim on its own | `drop` |
| **n=1** — one occurrence, or a repeat? | evidence names a second occurrence, or the single one cost a round, a blocker, or a merge | `demote` |
| **Root cause** — a cause, or a symptom of another `RF-N`? | no other finding shares its cause | `merge` |
| **Owner** — would the fix land in the doc that owns the behavior, in the repo that owns the doc? | owner doc and target repo both hold the behavior | `reroute` |
| **Counterfactual** — would this proposal have prevented the friction actually observed? | the mechanism connects proposal to observed friction | `drop` |
| **Ceremony price** — does the fix cost more per run than the friction it removes (per [Effort Scaling](skill://retro/docs/effort-scaling.md))? | the recurring cost is smaller than the recurring friction | `demote` |
| **Floor erosion** — does it thin a hard floor while claiming not to? | every floor stands untouched | `escalate` |
| **Status-quo steel-man** — is current behavior right and this run atypical? | the friction survives the best case for leaving things alone | `demote` |

For `lookback` runs, also confirm every aggregate and finding is scoped to the named window.

Check `What went well` against the same source test: an item with no citable evidence is ceremony, and gets cut.

## Verdicts

Verdicts land on the existing disposition vocabulary; they add no second axis.

- `survives` — finding stands as drafted.
- `demote` — disposition drops to `monitor`: friction real, case thin.
- `merge` — folded into the `RF-N` that owns the root cause.
- `reroute` — owner doc or target repo replaced.
- `drop` — removed from the report; name the cited evidence that failed.
- `escalate` — disposition becomes `human-decision`; the proposal becomes the question to ask.

Every verdict carries the counter-argument behind it, including `survives` — a survivor with no stated counter-argument is an unrefuted finding, so state the strongest one and why it loses. Dropped and merged findings stay visible in the report's Refutation log so the next retro does not re-raise them.

Prefer `demote` to `drop` when the friction was observed but its cause is unclear: `monitor` exists to hold exactly that.

## Refuter boundary

- **Verdicts only.** The refuter judges the drafted findings; it does not add findings, rewrite bounded proposals, or re-run the signal catalogue.
- **Read-only.** Re-reading cited sources, the repo, and the tracker is the whole toolkit; it mutates nothing and files nothing.
- **The safety floor check is the refuter's attestation**, not the drafter's: it confirms the floor list in [Effort Scaling](skill://retro/docs/effort-scaling.md) and lists every finding it escalated.
