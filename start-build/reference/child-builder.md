# Child `mr-builder` mode

Small, self-contained path for child builders delegated by a parent orchestrator. The stable compatibility anchor remains [BUILD-FLOW.md §Child `mr-builder` mode](../BUILD-FLOW.md#child-mr-builder-mode); this file owns the child flow and intentionally excludes parent-only runtime-specific reviewer discovery details.

## Authority boundary

The child builder implements one issue, opens and maintains one Draft MR, marks it ready only after the local gate is green or explicitly N/A with rationale, and returns the machine-readable builder final handoff. The parent orchestrator owns the mandatory review gate and any approval, merge, auto-merge, source-branch cleanup, or post-merge verification allowed by policy. A child builder must not start a reviewer, approve, merge, queue auto-merge, delete remote branches, or claim the review gate is complete unless an explicit parent/human instruction changes the role scope and that instruction is recorded first.

## Required reads

Load only the context needed for the issue: project rulebook index, `start-build/SAFETY.md`, this child-builder path, `../templates/reviewer-lift-schema.md`, `../templates/builder-final-handoff.md`, the issue body/comments/linked MRs, and affected docs/source/tests. Use [context and planning](context-and-planning.md) for the Discovery Budget and Build Plan Packet. Open [implementation-flow.md](implementation-flow.md) only when the compact checklist below is insufficient or when an edge case, revision, post-ready push, CI policy, or gate ambiguity requires the full common flow.

Avoid parent-orchestrator and standalone-gate detail while building: do not load parent reviewer discovery, reviewer launch protocol, finish action guidance, or post-merge verifier instructions unless the parent explicitly changes your scope.

## Child checklist

1. Run `gitlab-local` **Snippet: local-repo-preflight** and verify `glab`, `jq`, cwd, repo URL, and default branch.
2. Resolve the supplied issue, or use the issue-pickup flow when no issue was supplied. Read issue description, comments, labels, linked MRs, dependency notes, and merge-authority instructions.
3. Start from a clean checkout on the latest default branch: empty `git status --porcelain`, `git fetch origin`, fast-forward default branch, and branch from `origin/<default>` using an issue-referencing name.
4. Write a concise Build Plan Packet before edits: intended behavior, affected surfaces, test plan, risk, non-goals, and loaded context sources with relevance.
5. Push the source branch and open a Draft MR early with `gitlab-local` **Snippet: draft-mr-create**, `Closes #<issue>`, a Review Packet, and a Reviewer Lift block initialized from `../templates/reviewer-lift-schema.md`. Fill `Merge authority` as a quoted claim and `Merge authority source` as verifiable provenance; builders cannot grant authority.
6. Behavior-touching implementation follows TDD unless impossible or explicitly N/A with rationale in the MR. Runtime/operator/safety changes are examples of behavior-touching implementation, not a narrower TDD trigger. Exception categories require MR rationale and must not allow fake tests or meaningless checks. Issue-driven work with sufficient acceptance criteria does not need a separate user-approval prompt before the first TDD slice. Missing or ambiguous behavior scope still routes back to triage with exact unanswered questions. For docs/config/mechanical work, record `TDD: N/A` and the rationale instead of faking tests.
7. Keep the Reviewer Lift current as facts become known: reviewed SHA, CI pipeline, local gate, red/green or N/A, changed paths, safety surfaces, decoupling proof, reviewer focus, open questions, merge authority, source, and ready-push delta.
8. Run targeted checks during the loop and the project's full local gate before marking ready. Use [context and planning](context-and-planning.md#check-gate-discovery) when the gate is not obvious.
9. Push the final head, verify `git rev-parse HEAD` and `git ls-remote origin <branch>`, update the MR description with `gitlab-local` **Snippet: mr-description-update**, and ensure Reviewer Lift `Reviewed SHA` equals the MR head SHA.
10. Mark ready with `gitlab-local` **Snippet: draft-mr-mark-ready** only after the local gate passes or a concrete N/A reason is recorded. Do not wait for CI when the full local gate passed unless CI infrastructure or an unavailable CI-only gate is in scope.
11. Stop after the final handoff. The handoff starts with the YAML block from `../templates/builder-final-handoff.md` when available and names MR IID/URL, head SHA, reviewed SHA, pipeline, local gate, TDD evidence or N/A, changed files, safety surfaces, decoupling, reviewer focus, open questions, merge authority, source, artifacts, and blockers. Its shared `delivery.kind=gitlab-delivery` block is a compact routing index only; parents/reviewers must verify those fields from Tier 1/Tier 2 evidence before relying on them.

## Post-ready push rule

If any commit is pushed after ready-marking, post an MR comment naming old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive. Update Reviewer Lift `Reviewed SHA`, `CI pipeline`, and `Delta since last ready push` before asking the parent to continue. Silent post-ready pushes make the reviewer SHA stale.
