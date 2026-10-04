# Issue pickup flow

Detailed issue-resolution procedure for `start-build`. This file is the canonical owner of the full selection and suitability checklist.

## Procedure

1. Run `forge preflight` to confirm the current checkout and selected-provider repository binding resolve to the intended repository. If it fails, stop and ask.
2. Use `forge snapshot` to list candidates when the caller did not supply a work item. Narrow with labels, assignment, author, or milestone only when project conventions support those filters.
3. Inspect enough candidates to validate fit and coupling. For a normal queue, inspect 3-5 candidates; for a supplied work item, inspect that work item and its linked change requests. For every inspected work item, read its description and all current discussion before planning or editing. Treat discussion as scope, authority, and safety facts; where a description is stable and discussion is active, discussion carries the current state. Reconcile contradictions using source precedence; when precedence does not resolve them, stop for human escalation rather than guessing.
4. Prefer open work items that are unassigned or assigned to you, ready/triaged, clear, unblocked, non-confidential, and sized for one change request.
5. Deprioritize blocked work items, work items with information-needed or human-decision equivalents, WIP/in-progress work items, and confidential/security-sensitive work items unless the user explicitly supplied them.
6. For multiple work items, select only a set that satisfies the shared [Decoupling Contract](../../reference/decoupling-contract.md). If any contract item is false, unknown, or contradicted, do not parallelize.
7. Summarize each inspected candidate with ID, title, labels, assignee, suitability, and coupling risk before proceeding when there is a real choice.
8. Claim work items only when the target project's rulebook documents that convention. Do not create labels or mutate assignment casually.
9. Immediately before starting work, re-read the chosen work item's assignee and state; if it changed since selection or is already assigned to another active session, stop and ask rather than opening a competing branch or Draft change request.

## Supplied work-item fast path

When the user or parent supplies a work-item ID or locator, use it if it is open and within scope. Apply the same description-and-current-discussion read and contradiction handling from the canonical procedure above, then read linked change requests, dependency discussion, project rulebook, and affected docs/tests before editing.
