# Cleanup gates

Apply the applicable sequence to each candidate. Any **yes** is OUT. Any **unknown** uses the [`Needs info` classification](../SKILL.md#classification-rules) with the missing proof named and cannot be AFK.

## DESLOP gate sequence

A candidate's **declared observability budget** is the inspected file, its direct importers, and tests/fixtures, all listed in Candidate Evidence. An unstated or unbounded budget is unknown.

1. **Export gate** — exported, public, or referenced across a module boundary?
2. **Reference gate** — within the declared budget, referenced by another unit, including tests, mocks, reflection, DI, or dynamic access?
3. **Incidental-contract gate** — changes exception/message, log format, complexity class, ordering, rounding, or side-effect timing?
4. **Domain gate** — could the structure be a domain rule (branch table, tier, state machine) without proof that it is incidental?
5. **Edge gate** — creates, removes, or relocates an edge between units, including cross-unit dedup?

Treat every transform as observable until proven otherwise. An unproven transform is OUT, not a judgment call.

## DESTALE gate sequence

A finding is in scope only when one mechanical source proves both the drift and corrected value: command output, lockfile, config, or code signature. Treat stale text as a map, not truth, and never correct from inference.

Candidate Evidence must name the source and show both values. Without that proof, propose no correction: concrete drift with a named missing source uses the [`Needs info` classification](../SKILL.md#classification-rules); otherwise omit it as OUT. A fix requiring judgment, prose authoring, or a domain call is OUT of destale under that classification; edit CONTEXT.md/ADRs manually if the gap is real.

"Fix the drifted README command" is IN; "rewrite the README for clarity" is OUT.
