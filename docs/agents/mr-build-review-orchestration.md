# MR Build/Review Orchestration Design Brief

Status: historical design brief from issue #55. Active workflow policy now lives in
`/start-build`, `/start-review`, `/gitlab-local`, and `docs/agents/dev-workflows.md`.
Use this file for rationale and provenance only; do not treat it as a command
reference, schema source, or future implementation plan.

## What this brief still owns

This brief records why the GitLab issue-to-MR loop was split across reusable
skills and child agents:

- Parent orchestrators own issue selection, builder/reviewer fan-out, revision
  routing, CI/merge decision points, and cleanup.
- Child `mr-builder` sessions own one issue branch, one Draft MR, one Review
  Packet, local gate evidence, ready-marking, and final handoff.
- Fresh `mr-reviewer` sessions own independent diff review, one durable GitLab
  Review Report, one parseable final handoff, and one SHA-bound
  approval/request-changes/reject decision.
- `/gitlab-local` owns MCP-first GitLab transport contracts, guarded `glab`
  fallback syntax/flag pitfalls, file-backed GitLab writes, SHA guards, CI
  snapshots/watchers, and authority-aware finish snippets.
- Repo-local docs point at active skills instead of copying workflow bodies.

Durable rationale: keep review independence visible, bind decisions to exact
MR head SHAs, keep GitLab transport syntax/guards in one place, and avoid parent
prompts needing to restate every builder/reviewer safety boundary.

## Active sources of truth

For the canonical routing table to active workflow skills, schemas, templates,
and GitLab transport references, see [Dev Workflows](dev-workflows.md). This
brief does not duplicate that pointer table; `docs/agents/dev-workflows.md`
owns repo workflow routing per the `CLAUDE.md` doc ownership map.

## Historical outcome

The original brief proposed a parent-orchestrator loop, machine-readable
handoffs, safer file-backed GitLab comments, SHA-pinned CI/finish helpers,
explicit child-agent authority boundaries, and a read-only post-merge verifier
recipe. Those active contracts have since moved to the files linked above.

This file intentionally no longer includes:

- YAML schema bodies for builder or reviewer handoffs;
- shell snippets for MR descriptions, comments, CI watching, or MR finishing;
- step-by-step parent/reviewer/builder procedures;
- follow-up issue slices that imply unapproved or future-only work.

## Historical placement rationale

| Decision | Rationale |
| --- | --- |
| Parent loop lives in `/start-build` | Build flow already owns issue pickup, Draft MR creation, Review Packet upkeep, local gate evidence, ready-marking, and handoff to the mandatory review gate. |
| Review decisions live in `/start-review` | Reviewer flow owns fresh-session review, Review Report shape, finding IDs, SHA-bound approval decisions, and merge-authority limits. |
| GitLab transport details live in `/gitlab-local` | MCP tools and fallback `glab` flags/JSON shapes drift by version; one transport reference avoids stale snippets in repo docs and prompts. |
| Machine handoff templates live beside producer flows | Builders/reviewers produce those blocks, while parent orchestrators consume them opportunistically and fall back to MR descriptions/comments. |
| Repo docs stay pointer-first | `docs/agents/dev-workflows.md` can route agents to canonical skill docs without becoming another policy copy. |
| Post-merge verification stays separate from review | Read-only verification after merge should not grant reviewer, builder, or verifier extra approval/merge authority. |

## What remains intentionally non-canonical here

This brief may still help explain past design choices, but it must not be used to
answer operational questions such as which command to run, which fields a Review
Packet needs, whether a child builder may spawn a reviewer, or who may approve or
merge an MR. For those answers, load the active sources above.

No current future implementation checklist is maintained in this file. New
workflow changes should start as fresh GitLab issues and update the canonical
source that owns the behavior.
