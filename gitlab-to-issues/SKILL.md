---
name: gitlab-to-issues
description: Break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues for the current target GitLab repo using tracer-bullet vertical slices and target-repo triage labels. Use when the user asks for /gitlab-to-issues, GitLab issue creation, or a GitLab-specific breakdown for AFK/HITL agents; keep generic /to-issues (if installed) separate.
---

# GitLab To Issues

Turn an approved plan into GitLab issues for the current target GitLab repository using that repo's Agent Setup Docs and triage labels. This skill intentionally uses the distinct `gitlab-to-issues` name so it does not shadow a generic `/to-issues` skill if installed.

## Quick start

1. Load `/gitlab-local` and run **Snippet: local-repo-preflight** from the intended target repository before any publishing work.
2. Resolve the target repo root with `git rev-parse --show-toplevel`; treat that path as `<repo-root>` for all repo-local docs.
3. Read target docs from `<repo-root>/docs/agents/issue-tracker.md` and `<repo-root>/docs/agents/triage-labels.md`. Do not read these docs from the skill installation directory.
4. If either target tracker doc is missing, or if `<repo-root>/docs/agents/issue-tracker.md` does not say the tracker is GitLab, stop and ask the user to set up or choose the correct workflow.
5. Before drafting or publishing, display the detected GitLab target as host/project (for example, `gitlab.example/group/project`) from `/gitlab-local` preflight/repo metadata and ask the user to confirm it if there is any ambiguity.
6. If the source is an issue, PRD, URL, or file, fetch/read its full body and comments.
7. Explore only enough context to name slices accurately: glossary terms from `<repo-root>/CONTEXT.md` when present, relevant ADRs under `<repo-root>/docs/adr/` when present, current seams, and coupling risk.
8. Draft tracer-bullet slices; ask the user to approve the breakdown before publishing.
9. Publish approved slices to GitLab using `/gitlab-local` command syntax only after explicit publish approval.

## Slice rules

Each issue is a thin vertical slice through all affected user-visible layers: docs, CLI behavior, Dev Workflow guidance, state, API, UI, tests, deploy/runbook, or other observable surfaces. Do not assume every project has schema/API/UI. Each slice should be demoable, reviewable, and testable on its own.

## Slice types and labels

Use only labels listed in `<repo-root>/docs/agents/triage-labels.md`; never invent or rely on lazy label creation. That file owns the live vocabulary; this section only describes when to look there.

- **AFK**: implementable without new human decisions. Normal review/merge policy still applies; AFK means ready for an agent, not review bypass. Fill the [Agent Readiness](templates/issue-body.md#agent-readiness) section and apply the repo's AFK-ready label only if `<repo-root>/docs/agents/triage-labels.md` defines one and the readiness section passes or has a maintainer waiver.
- **Docs**: documentation-only or documentation-focused slice. Apply a docs kind label only if `<repo-root>/docs/agents/triage-labels.md` defines one.
- **Refactor**: structure-improvement slice. Apply a refactor kind label only if `<repo-root>/docs/agents/triage-labels.md` defines one.
- **HITL**: requires human decision, design review, architecture choice, product judgment, security/legal judgment, or another choice an agent must not invent. If no live label exists, state `Type: HITL` in the issue body.
- **Needs info**: unclear, missing acceptance criteria, blocked by unknowns, or not safe to hand to an agent yet. If no live label exists, state `Type: Needs info` and the blocker in the issue body.

## Draft workflow

For each proposed slice, show:

- **Title**: short, domain-language title
- **Type**: AFK / HITL / Needs info
- **Blocked by**: issue title or dependency, if any
- **User stories covered**: source user stories this slice satisfies
- **Acceptance criteria**: concrete, verifiable checks
- **Agent Readiness**: acceptance criteria quality, current-state/repro evidence, test strategy, risk surface, dependencies, unknowns, AFK safety, and reviewer focus
- **Coupling risk**: files/seams/safety surfaces likely to overlap other slices

Ask the user whether granularity, dependencies, splitting/merging, and AFK/HITL/Needs info classifications are right. Iterate until approved.

## Publishing workflow

Publish approved issues in dependency order so later issues can reference real blockers. Do not close or modify parent issues unless the user explicitly asks.

Before publishing, show the user the detected GitLab target, labels to apply, issue count, and issue titles, then ask for explicit approval to publish. If approval is not explicit, do not create issues.

Use `/gitlab-local` for all `glab` command syntax, flags, comments, labels, and known pitfalls. Never paste secrets or sensitive payloads into issue bodies or comments. Apply mapped labels only when they exist in `<repo-root>/docs/agents/triage-labels.md`; otherwise record the slice type in the issue body.

For generated AFK issues, preserve the `## Agent Readiness` section from the issue body template. If any readiness field lacks durable context and no maintainer waiver exists, publish the slice as HITL or Needs info instead of applying an AFK-ready label.

## Issue body template

Use [templates/issue-body.md](templates/issue-body.md) as the starting point for each published issue body. Keep the AFK/HITL/Needs info type, parent reference, vertical-slice description, user stories, acceptance criteria, Agent Readiness section, out-of-scope notes, safety/evidence notes, and blocker details intact unless the approved breakdown requires a narrower value.
