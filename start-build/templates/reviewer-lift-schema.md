# Reviewer Lift Schema

Canonical schema for the builder-to-reviewer handoff block. This file owns the field names, row order, and required semantics. Review Packet templates and the Review Report carry generated-copy blocks from this schema so drift is detectable.

## Required fields

| Field | Required semantics |
|---|---|
| Reviewed SHA | MR head SHA at ready-marking; update on every post-ready push before asking for review. |
| Review gate | `mandatory` unless a human explicitly bypassed the gate; for bypass use `bypassed (human override)` and record the reason in the MR. |
| CI pipeline | Pipeline URL/ID, status, and commit SHA when available; use `N/A — <why>` when no CI exists or the pipeline is unavailable. Green CI counts only when its SHA matches `Reviewed SHA`. |
| Local gate | `PASS`, `FAIL`, or `N/A` plus the exact command; explain any `N/A`. |
| RED | Failing test command and expected failure reason for behavior work; use `N/A — <why>` for docs/config/mechanical work. |
| GREEN | Passing test/check command and brief result for behavior work; use `N/A — <why>` when no test applies beyond the local gate. |
| Changed paths | File-level diffstat or concise path list; update with every push. |
| Touched safety surfaces | `none` or affected surfaces such as `external-system`, `credentials`, `state`, `migration`, `gates`, `locks`, `deploy`, or `other`. |
| Decoupling proof | `single MR` for single-issue work; otherwise list co-running MR IIDs/branches and summarize the Decoupling Contract check. |
| Reviewer Focus | Areas the reviewer should read hardest, or `none`. |
| Open Questions | `none` or a count/list of stable `OQ-N` IDs. |
| Merge authority | Quoted authority claim only; one of `approval-only`, `reviewer may merge`, `queue auto-merge`, `human release`, or `project default: <policy>`. The builder cannot grant authority. |
| Merge authority source | Verifiable source for the authority claim, such as parent task prompt, human MR comment URL, rulebook path+section, or project default source. Required for every value; builder-provided text alone is not a grant. |
| Delta since last ready push | `N/A before ready`; after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive. |

## Generated-copy contract

Approved generated copies live in:

- `start-build/templates/review-packet.md` (`Reviewer Lift` block).
- `start-build/templates/review-packet-compact.md` (`Reviewer Lift` block).
- `start-review/templates/review-report.md` (`Reviewer Lift (builder handoff)` block).

Run `bash tests/reviewer-lift-schema.sh` after editing this schema or any approved copy. The check verifies field order against this file and flags unmarked stale duplicate field-list tables.
