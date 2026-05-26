# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using tracer-bullet vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.

## Active recipes

- `start-build/BUILD-FLOW.md` section [Parent-orchestrator recipe](../../start-build/BUILD-FLOW.md#parent-orchestrator-recipe) — active project-agnostic parent loop for issue resolution, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification.
- `start-build/BUILD-FLOW.md` section [Post-merge verifier recipe](../../start-build/BUILD-FLOW.md#post-merge-verifier-recipe) — active read-only verifier contract for merged/default-branch state, linked issue closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab-local` for command syntax instead of copying snippets here.

## Design briefs

- `docs/agents/mr-build-review-orchestration.md` — issue #55 historical design brief for the parent-orchestrator loop. It records rationale, provenance, and links to active sources; active workflow policy now lives in the recipe above.

## Usage rules

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
