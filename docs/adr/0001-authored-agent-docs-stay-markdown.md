# ADR-0001: Authored agent docs stay Markdown

## Status

Accepted

## Context

At commit `b4a33ef`, the `CLAUDE.md` ownership-map table measured 2,237 bytes, approximately 526 tokens, as Markdown. Re-encoding the same rows produced these relative sizes:

- TOON with comma delimiters: 2% smaller
- TOON with tab delimiters: 10% smaller
- JSON: 39% larger

Prose accounts for 87% of the table's bytes, so serialization overhead is not the main cost driver. Markdown tables also retain GitLab rendering and model familiarity.

## Decision

Authored agent documentation in this repository stays in Markdown. This includes `CLAUDE.md`, `*/SKILL.md`, files under `docs/`, and reference and template files. TOON (Token-Oriented Object Notation) is rejected as a format for authored documentation.

TOON remains acceptable for transient, machine-generated tabular runtime payloads exchanged between agents, such as issue batches or pipeline listings, only when a concrete, measured context-pressure problem appears. This exception never applies to authored documentation.

## Consequences

Future proposals to change the format of authored agent documentation should follow this decision. Token-reduction work should instead tighten prose and is outside the scope of this ADR.
