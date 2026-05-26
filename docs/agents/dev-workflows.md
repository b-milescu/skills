# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using tracer-bullet vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.

## Design briefs

- `docs/agents/mr-build-review-orchestration.md` — issue #55 design brief for a project-agnostic parent-orchestrator loop. It is recommendation material, not active workflow policy, until follow-up implementation issues are approved.

## Usage rules

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
