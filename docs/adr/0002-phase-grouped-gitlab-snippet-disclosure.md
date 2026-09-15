# ADR-0002: Phase-grouped GitLab snippet disclosure

## Metadata

| Field | Value |
|---|---|
| Number | 0002 |
| Title | Phase-grouped GitLab snippet disclosure |
| Status | `Accepted` |
| Date | 2026-09-15 |
| Author | agents/skills maintainers |
| Deciders | Human decision recorded on issue #469 |
| Supersedes | — |
| Safety surfaces | `none` |

## Context

`gitlab/SKILL.md` is the selected GitLab transport branch reached through `/forge` disclosure. The skill-activation mechanic documented in [`docs/agents/dev-workflows.md`](../agents/dev-workflows.md#skill-activation-mechanism) makes a `SKILL.md` body **all-or-nothing** on invocation, while files under `reference/` are read per-need.

Measured at baseline commit `e2dbcd266f44b4aa1acac254914654415ef7e9c9`:

- `gitlab/SKILL.md` was 6,645 tok, of which the 21 `### Snippet:` bodies were 4,160 tok (63 percent), by section scan.
- A build run needs about 6 of the 21 snippets; a review run about 11.
- Exactly one caller repo-wide names a snippet by name (`docs/agents/issue-tracker.md` names `issue-pickup`), so snippet selection happens by reading the catalogue.
- 25 assertions in `tests/gitlab-split-snippets.sh` and 15 in `tests/gitlab-mcp-first-workflows.sh` pinned `gitlab/SKILL.md` as the snippet home.

Every GitLab-bound run therefore paid for all 21 snippet bodies to select roughly a third of them.

## Decision

Move the 21 snippet bodies out of `gitlab/SKILL.md` into three phase-grouped reference files, and keep the snippet index, the transport order, the help-first rule, the multi-action guard-order warning, the Mutation Guard pointer, the issue publication contract, the three closure oracles, and the safe-text rules in the entry procedure.

| Group file | Phase | Snippets |
|---|---|---|
| `gitlab/reference/snippets-read-evidence.md` | read and evidence | `local-repo-preflight`, `issue-pickup`, `mr-pickup`, `artifact-capture`, `safe-mr-json`, `sha-guard`, `ci-decision-snapshot`, `ci-watch-sha-pinned`, `approval-confirmation`, `mr-handoff-evidence` |
| `gitlab/reference/snippets-publish-body.md` | publish and body | `draft-mr-create`, `mr-description-update`, `draft-mr-mark-ready`, `mr-note-create`, `issue-note-create`, `label-reconcile` |
| `gitlab/reference/snippets-mutate-finish.md` | mutate and finish | `sha-bound-approval`, `sha-bound-merge`, `sha-bound-auto-merge-queue`, `auto-merge-api-fallback`, `finish-mr-authority-aware` |

The 21 snippet names and their contracts are unchanged workflow API. Bodies moved verbatim; the only deviations are heading depth (`### Snippet:` became `## Snippet:`), three same-file `#gitlab-mutation-guard` fragment links rewritten to `skill://gitlab/SKILL.md#gitlab-mutation-guard` now that they cross a file boundary, and the shared multi-action guard-order warning paragraph, which governs every action snippet and stayed in the entry procedure verbatim.

## Rationale

A run pays the entry procedure unconditionally and each group file only when its phase needs it. Keeping the index in the entry procedure is what caps the saving at roughly half the theoretical maximum, and it is required: selection happens by reading the catalogue, so a run that cannot see the catalogue cannot pick a snippet.

Expected effect: 2,000 to 3,000 tok off a GitLab-bound run, at the cost of 1 to 2 extra reference reads.

## Alternatives Considered

- **Status quo (no move).** Rejected: keeps a ~4,160 tok unconditional load for snippets a run does not use.
- **Per-snippet files (21 files).** Rejected: saves more (3,900 to 6,100 tok per run) but costs 6 to 11 extra reads per run, rewrites all 40 assertions that pin `SKILL.md` as the snippet home, and maximally enlarges the hazard named in [`docs/agents/dev-workflows.md`](../agents/dev-workflows.md) (issue #320) — an agent satisfying a prompt with a raw reference read that skips the entry procedure, which is where guard order lives.
- **Generated from `snippet-metadata.json`.** Rejected: a metadata-only source with an on-demand renderer adds a script dependency inside the mutation path and conflicts with the mirror removal in issue #460.

## Consequences

### Positive

- The unconditional cost of the GitLab transport skill drops to the index plus guard order.
- Phase grouping matches how runs consume snippets, so one extra read usually covers a whole phase.
- The grouping rationale is durable instead of tribal.

### Negative

- One indirection between selecting a snippet name and reading its body.
- Three files to keep synchronized with `snippet-metadata.json` instead of one.

### Operational / Safety Impact

None. Guard order, the Mutation Guard pointer, the help-first rule, and the multi-action warning stay in the entry procedure, so the issue #320 hazard is not widened. No runtime, state, credential, or deploy surface is touched.

### Migration Plan

Landed in one change: bodies moved, index added, and the assertions that pinned `SKILL.md` as the snippet home re-homed against the group file that now holds each text. The hard count of 21 survives as a sum across the three group files, so the name-stability guarantee is preserved rather than dropped.

## Compliance / Enforcement

- `tests/gitlab-split-snippets.sh` and `tests/gitlab-mcp-first-workflows.sh` assert the 21 stable names and per-snippet bodies against the group files, and sum the count to exactly 21.
- `tests/gitlab-snippet-metadata.sh` keeps the group-file name set equal to `snippet-metadata.json` and the `snippet-transports.md` table.
- `npm run check:links` validates the inbound reference from `gitlab/SKILL.md` and the group files.

## Revisit When

- A run's snippet selection stops matching these three phases (for example a phase routinely reads two group files).
- The index itself becomes the dominant cost in the entry procedure.
- Callers start naming snippets directly often enough that the catalogue no longer needs to be in the entry procedure.

## References

- Issue #469 — decision record and acceptance criteria.
- [`docs/agents/dev-workflows.md`](../agents/dev-workflows.md#skill-activation-mechanism) — skill activation mechanic.
- [`gitlab/reference/snippet-transports.md`](../../gitlab/reference/snippet-transports.md) — per-snippet transport contracts.
- [ADR-0001](0001-authored-agent-docs-stay-markdown.md) — authored agent docs stay Markdown.
