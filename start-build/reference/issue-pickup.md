# Issue pickup flow

Detailed issue-resolution procedure for `start-build`. This file is the canonical owner of the full selection and suitability checklist.

## Procedure

1. Run `gitlab` **Snippet: local-repo-preflight** to confirm cwd is the intended GitLab repo and MCP/fallback project binding resolves to it. If it fails, stop and ask.
2. Use `gitlab` **Snippet: issue-pickup** to list candidates when the caller did not supply an issue. Narrow with labels, assignment, author, or milestone only when project conventions support those filters.
3. Inspect enough candidates to validate fit and coupling. For a normal queue, inspect 3-5 candidates; for a supplied issue, inspect that issue and its linked MRs. For every inspected issue, read the issue description and all current issue notes before planning or editing. Treat notes as scope, authority, and safety facts; where a description is stable and notes are active, notes carry the current state. Reconcile contradictions using source precedence; when precedence does not resolve them, stop for human escalation rather than guessing.
4. Prefer open issues that are unassigned or assigned to you, ready/triaged, clear, unblocked, non-confidential, and sized for one MR.
5. Deprioritize blocked issues, issues with information-needed or human-decision equivalents, WIP/in-progress issues, and confidential/security-sensitive issues unless the user explicitly supplied them.
6. For multiple issues, select only a set that satisfies the shared [Decoupling Contract](skill://start-build/docs/decoupling-contract.md). If any contract item is false, unknown, or contradicted, do not parallelize.
7. Summarize each inspected candidate with ID, title, labels, assignee, suitability, and coupling risk before proceeding when there is a real choice.
8. Claim issues only when the target project's rulebook documents that convention. Do not create labels or mutate assignment casually.
9. Immediately before starting work, re-read the chosen issue's assignee and state; if it changed since selection or is already assigned to another active session, stop and ask rather than opening a competing branch or Draft MR.

## Supplied issue fast path

When the user or parent supplies an issue ID or URL, use it if it is open and within scope. Apply the same description-and-current-notes read and contradiction handling from the canonical procedure above, then read linked MRs, dependency notes, project rulebook, and affected docs/tests before editing.
