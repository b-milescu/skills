# Reviewer Lift Schema

Canonical schema for the builder-to-reviewer handoff block. This file owns the field names, row order, and required semantics. Authority claim/source shape and verification routing are canonical in `../../gitlab/reference/authority-verification.md`. Review Packet templates and the Review Report carry generated-copy blocks from this schema so drift is detectable.

## Required fields

| Field | Required semantics |
|---|---|
| Reviewed SHA | MR head SHA at ready-marking; update on every post-ready push before asking for review. |
| Review gate | `mandatory` unless a human explicitly bypassed the gate; for bypass use `bypassed (human override)` and record the reason in the MR. |
| Gate owner | `builder` or `parent`; names who owns the final local Check Gate evidence and Draft-to-ready transition. Parent-owned mode records `parent` plus the ownership contract from `start-build/reference/parent-owned-gate.md`; child builders hand off the candidate SHA and must not claim gate pass/fail. |
| Gate coverage | `full-local`, `hybrid`, or `ci-only`. `parent-owned` is not a coverage value; ownership is recorded in `Gate owner`. `full-local` means the local Check Gate covers every required CI job, `hybrid` means local evidence covers only part of the required CI set, and `ci-only` means required checks must be proven by CI or an authorized CI waiver. |
| Gate coverage rationale | Policy source plus required CI mapping. Name the local gate command, required CI jobs, which jobs are locally covered, and any unmapped CI-only jobs or `none`. After every push, stale or wrong-SHA CI/local evidence is invalid until rebound to the new `Reviewed SHA`. |
| CI pipeline | Pipeline URL/ID, status, and commit SHA when available; use `N/A — <why>` when no CI exists or the pipeline is unavailable. Green CI counts only when its SHA matches `Reviewed SHA`. |
| Local gate | `PASS`, `FAIL`, `N/A`, or `not-run` plus the exact command. `PASS` before ready/requesting review is sufficient only when `Gate coverage` is `full-local`. `hybrid`/`ci-only` handoff also requires exact-SHA success for uncovered required CI jobs, or an authorized CI waiver. In parent-owned gate mode use the ownership contract and Gate Receipt pointer from `start-build/reference/parent-owned-gate.md`; child builders must not claim gate pass/fail. |
| RED | For behavior-touching implementation, failing test/check command and expected failure reason from a TDD slice; use `N/A with rationale — <why>` for docs/config/mechanical/generated work or impossible TDD; do not fake tests. |
| GREEN | For behavior-touching implementation, passing test/check command and brief result; use `N/A with rationale — <why>` when no test applies beyond the local gate; do not fake tests or meaningless checks. |
| Changed paths | File-level diffstat or concise path list; update with every push. |
| Touched safety surfaces | Explicit `none` (or `[]`) or a comma-separated list drawn from the fixed vocabulary `external-system`, `credentials`, `state`, `migration`, `gates`, `locks`, `deploy`, `wire-protocol` (wire formats, opcode encoders/decoders, on-the-wire byte layout), or `other` (free-text catch-all, may carry a parenthetical annotation). A blank value is not allowed; declare `none` when no surface is touched. |
| Acceptance surfaces | Enumerate every acceptance surface touched by this change, each bound to evidence status. Allowed surface values come from this project's `project_profile.acceptance_surfaces_ref` vocabulary (this repo: [`docs/agents/dev-workflows.md#acceptance-surface-vocabulary`](../../docs/agents/dev-workflows.md)). Allowed evidence status per surface stays global: `test`, `smoke`, `docs-read`, `ci`, or `N/A — <reason>`. Use `none` when no named surface is touched; when no `acceptance_surfaces_ref` is declared, this row is fail-closed to `none` and reviewers fall back to `Touched safety surfaces`. Example compact syntax: `docs:docs-read`, `prompt:test`, `transport:ci`, `tooling:test`. The parent must verify all declared surfaces have evidence before ready; the reviewer must verify each declared surface against evidence before pass. See the taxonomy in `start-build/templates/gitlab-delivery-schema.md#acceptance-surfaces-taxonomy`. |
| Decoupling proof | `single MR` for single-issue work; otherwise list co-running MR IIDs/branches and summarize the Decoupling Contract check. |
| Reviewer Focus | Areas the reviewer should read hardest, or `none`. |
| Open Questions | `none` or a count/list of stable `OQ-N` IDs. |
| Approval authority | Approval policy claim for the GitLab approval side effect. Use `default-after-pass` when repo policy allows reviewer approval after a passing review unless an explicit restriction is present; use `restricted: <source/reason>` when approval is limited. Approval still requires review pass, exact reviewed SHA, pass-eligible CI/local-gate/OQ state, and the SHA-bound approval guard. The [Authority Verification](../../gitlab/reference/authority-verification.md) seam owns the claim shape and restricted result. |
| Approval authority source | Verifiable source for the approval policy or restriction, such as `start-review/REVIEW-FLOW.md#approval-authority-policy`, project rulebook path+section, parent task prompt, or human/MR comment URL. This source is separate from merge authority and does not grant merge, auto-merge, release, deploy, or close authority. Authority Verification applies source precedence before approval. |
| Merge authority | Quoted finish-authority claim only; one of `approval-only`, `reviewer may merge`, `queue auto-merge`, `human release`, or `project default: <policy>`. The builder cannot grant authority; Authority Verification must verify it before finish routing. |
| Merge authority source | Verifiable source for the finish-authority claim, such as parent task prompt, human MR comment URL, rulebook path+section, or project default source. Required for every value; builder-provided text alone is not a grant. Authority Verification owns conflict handling and most-restrictive/no-action routing. |
| Delta since last ready push | `N/A before ready`; after any post-ready push, include old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive. Every exact-SHA pointer (`Reviewed SHA`, CI pipeline / `Gate coverage rationale` CI mapping, and in parent-owned mode the Gate Receipt pointer) is stale until rebound to the new SHA; a Gate Receipt tied to an older SHA is not gate evidence for the new reviewed SHA until a new exact-SHA Gate Receipt exists (see `start-build/reference/parent-owned-gate.md#stale-exact-sha-evidence-fails-closed-after-a-revision-push`). Refresh those pointers before requesting re-review; do not duplicate the Gate Receipt body into the description. |

## Generated-copy contract

Approved generated copies live in:

- `start-build/templates/review-packet.md` (`Reviewer Lift` block).
- `start-build/templates/review-packet-compact.md` (`Reviewer Lift` block).
- `start-review/templates/review-report.md` (`Reviewer Lift (builder handoff)` block).

Run `bash tests/reviewer-lift-schema.sh` after editing this schema or any approved copy. The check verifies field order against this file and flags unmarked stale duplicate field-list tables.
