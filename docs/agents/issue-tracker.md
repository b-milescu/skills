# Issue tracker: GitLab

Issues, PRDs, and merge requests for this repo live on the self-hosted GitLab instance at `gitlab.example.com` in project `agents/skills` (`https://gitlab.example.com/agents/skills`).

Use `/forge` from this verified target clone with the selected
[project-native recipes](native-integration.md). These are this project's facts,
not an installed shared profile or a default for foreign targets.

## Repo conventions

- GitLab issues are the tracker items for tasks and PRDs.
- GitLab merge requests are the review vehicle for code, docs, and workflow changes.
- Comments are native notes; the [project integration](native-integration.md) owns exact tools, complete reads and publication readback.
- Labels follow this repo's triage vocabulary; see `docs/agents/triage-labels.md`.
- Follow native cursor recovery for complete discovery; lists are not single-item guard evidence.
- Verify intended repository against named fetch/push/fork configuration and native project metadata; never infer work-item scope solely from code-host branding.
- Branch naming is project policy, not a GitLab schema rename. This repo declares
  it in [`docs/agents/dev-workflows.md`](dev-workflows.md#branch-naming) as
  `project_profile.branch_naming`; shared delivery fields remain
  `change_request.source` and `change_request.target`.

## Claiming convention

This section is the rulebook-documented claiming convention that the shared
issue-pickup flow's conditional-claim rule (set the assignee only when the
target project's rulebook documents such a convention) conditionally requires.

- **Claim at pickup:** before opening a branch or Draft change request, a
  delivery session assigns the chosen work item to its authenticated tracker
  identity (the identity `forge preflight` binds for that session).
- **Release when work stops:** when work on the item stops — delivered (change
  request merged or review handed off), blocked, or abandoned — the session
  releases the claim in that same stopping step, so a stale claim never
  permanently blocks pickup.
- **Why the claim exists:** it gives the pickup flow's pre-launch assignee
  re-read its signal. A second session re-reading the item before launch sees
  the claim and stops to ask instead of racing the first session. The
  mechanism and its stop-and-ask semantics live in the pickup skill
  (`start-build/reference/issue-pickup.md`, steps 8–9); this file documents
  the convention only and does not restate the skill's procedure.
- **Labels:** the claim uses assignee only. It creates no labels, stays within
  the live label vocabulary in
  [`docs/agents/triage-labels.md`](triage-labels.md), and adds no tooling or
  enforcement automation.

## When a skill says "publish to the issue tracker"

Create a native issue in this verified project using `/forge publish` and the [project integration](native-integration.md). Approved plans/specs/PRDs use `/plan-to-issues`.

## When a skill says "fetch the relevant ticket"

Read the full referenced issue and all discussions through `/forge snapshot` and the [project integration](native-integration.md).

## Reconcile on unblock

When a merge closes an issue that an open issue names as a blocker or ordering constraint, update or strike that dependent issue's `Blocked by` / `Dependencies` text in the same step, so the next reader sees current tracker state instead of an expired constraint. This reconcile-on-unblock rule is bounded to that transition; it grants no licence to rewrite issue bodies otherwise.
