# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using tracer-bullet vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, and delivery metrics in one place. See [skill doc](../../issue-delivery-loop/SKILL.md).
- **`/post-merge-verifier`** — read-only post-merge verification after merge or protected auto-merge: default-branch state, linked issue closure or pending closure, CI evidence, source-branch cleanup, promised docs/ADR/follow-ups, and blockers. See [skill doc](../../post-merge-verifier/SKILL.md).

## Active recipes

- `issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps command syntax in `/gitlab-local`.
- `start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `/post-merge-verifier`; the stable compatibility anchor remains [BUILD-FLOW.md §Parent-orchestrator recipe](../../start-build/BUILD-FLOW.md#parent-orchestrator-recipe).
- `post-merge-verifier/SKILL.md` — active read-only verifier skill for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab-local` for command syntax instead of copying snippets here.

## Design briefs

- `docs/agents/mr-build-review-orchestration.md` — issue #55 historical design brief for the parent-orchestrator loop. It records rationale, provenance, and links to active sources; active workflow policy now lives in the recipe above.
- `docs/agents/workflow-reference-split-plan.md` — issue #90 planning artifact for future anchor-preserving splits of oversized active Dev Workflow reference docs. It does not move active workflow content or change GitLab command/review/build authority semantics.

## Usage rules

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
