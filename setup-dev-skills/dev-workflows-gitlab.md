# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, and delivery metrics in one place. See [skill doc](../issue-delivery-loop/SKILL.md).
- **`/post-merge-verifier`** — read-only post-merge verification after merge or protected auto-merge: default-branch state, linked issue closure or pending closure, CI evidence, source-branch cleanup, and blockers. See [skill doc](../post-merge-verifier/SKILL.md).

## Active recipes

- `issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps command syntax in `/gitlab-local`.
- `start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for GitLab issue-to-MR work: issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `/post-merge-verifier`; the stable compatibility anchor remains [BUILD-FLOW.md §Parent-orchestrator recipe](../start-build/BUILD-FLOW.md#parent-orchestrator-recipe).
- `post-merge-verifier/SKILL.md` — active read-only verifier skill for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab-local` for command syntax instead of copying snippets into generated setup docs.

When adapting this seed into `docs/agents/dev-workflows.md`, keep these active recipe pointers conceptually aligned with the target repo's workflow docs while leaving project-specific design briefs, labels, gate commands, and merge authority in the target repo's own setup docs.

## Usage rules

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md` / `AGENTS.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
- Issue readiness criteria are owned by `/gitlab-to-issues` and the target repo's triage-labels doc; setup does not generate a separate readiness doc.
