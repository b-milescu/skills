# Template Filling Guide — ADR

Architecture Decision Records capture hard-to-reverse decisions affecting future contributors, safety boundaries, or multiple subsystems.

- Commit ADRs under `docs/adr/NNN-kebab-title.md` (create `docs/adr/` if needed) via their own change request.
- **Context** — Problem, forces, current constraints, why now.
- **Decision** — One clear sentence if possible.
- **Rationale** — Why this shape wins.
- **Alternatives Considered** — One subsection per alternative, with pros / cons / rejection reason.
- **Compliance / Enforcement** — Tests, reviewer checks, lints, runbooks, startup guards, migrations.
- **Revisit When** — Concrete signal.
- **References** — Docs, prior reviews, source, external references.
