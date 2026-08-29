---
name: plan-to-issues
description: >-
  Break an approved plan, spec, PRD, or conversation into independently-grabbable
  tracker issues as vertical slices with target-repo triage labels. Use when the
  user asks for /plan-to-issues, "break this into issues",
  GitLab/GitHub/Azure DevOps issue creation, or an AFK/HITL breakdown.
---

# plan-to-issues

Turn an approved plan into tracker issues or work items for the current target repository using that repo's Agent Setup Docs and triage labels.

## Quick start

1. Invoke `/forge preflight` from the intended target repository before any publishing work.
2. Resolve the target repo root with `git rev-parse --show-toplevel`; treat that path as `<repo-root>` for all repo-local docs.
3. From the selected `project_profile`, bind `<issue-tracker-doc>` to `<repo-root>/<project_profile.agent_setup_docs.issue_tracker>` and `<triage-labels-doc>` to `<repo-root>/<project_profile.agent_setup_docs.triage_labels>`. Reuse these bindings for every target-repo tracker or label read; `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` are only the default profile's values.
4. Read `<issue-tracker-doc>` and `<triage-labels-doc>`. If either file is missing, stop and ask the user to set up or choose the correct workflow. Fail closed unless the tracker is GitLab, GitHub, or Azure DevOps; if it is local markdown, Other, or silent, stop and ask. Do not fall back to default-profile paths or read target docs from the skill installation directory.
5. Before drafting or publishing, display the preflight target (provider and canonical repository from `/forge`) and ask the user to confirm it if there is any ambiguity.
6. If the source is an issue, PRD, URL, or file, fetch/read its full body and comments.
7. Explore only enough context to name slices accurately: glossary terms from `<repo-root>/CONTEXT.md` when present, relevant ADRs under `<repo-root>/docs/adr/` when present, current seams, and coupling risk.
8. Draft vertical slices; ask the user to approve the breakdown before publishing.
9. After explicit publish approval, publish each approved slice as one `forge publish` tracker-issue or work-item artifact and require provider-native readback. The disclosed provider reference owns native create, labels, comments, safe-body, and fallback.

## Slice rules

Each issue is a thin vertical slice through all affected user-visible layers: docs, CLI behavior, Dev Workflow guidance, state, API, UI, tests, deploy/runbook, or other observable surfaces. Do not assume every project has schema/API/UI. Each slice should be demoable, reviewable, and testable on its own.

Slice *toward* the shared [Decoupling Contract](skill://plan-to-issues/docs/decoupling-contract.md): aim each slice at independence so a builder and reviewer can later grade it against that same contract. This skill references the contract for the independence target only; it does not enforce or prove decoupling — that stays with `/start-build`, `/start-review`, and `/issue-delivery-loop`.

## Slice types and labels

Use only labels listed in `<triage-labels-doc>`; never invent or rely on lazy label creation. That selected-profile file owns the live vocabulary; this section only describes when to look there.

- **AFK**: ready for an agent to implement; see the skill-owned [Agent Readiness scorecard](skill://plan-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard) for what that requires. Fill the [Agent Readiness](skill://plan-to-issues/templates/issue-body.md#agent-readiness) section and apply the repo's AFK-ready label only if `<triage-labels-doc>` defines one.
- **Docs**: documentation-only or documentation-focused slice. Apply a docs kind label only if `<triage-labels-doc>` defines one.
- **Refactor**: structure-improvement slice. Apply a refactor kind label only if `<triage-labels-doc>` defines one.
- **HITL**: requires human decision, design review, architecture choice, product judgment, security/legal judgment, or another choice an agent must not invent. If no live label exists, state `Type: HITL` in the issue body.
- **Needs info**: unclear, missing acceptance criteria, blocked by unknowns, or not safe to hand to an agent yet. If no live label exists, state `Type: Needs info` and the blocker in the issue body.

## Draft workflow

For each proposed slice, show:

- **Title**: short, domain-language title
- **Type**: AFK / HITL / Needs info
- **Blocked by**: issue title or dependency, if any
- **User stories covered**: source user stories this slice satisfies
- **Acceptance criteria**: concrete, verifiable checks
- **Agent Readiness**: the readiness fields from the [Agent Readiness scorecard](skill://plan-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard), filled via the [issue body template](skill://plan-to-issues/templates/issue-body.md#agent-readiness)
- **Coupling risk**: files/seams/safety surfaces likely to overlap other slices, graded toward the shared [Decoupling Contract](skill://plan-to-issues/docs/decoupling-contract.md)

Ask the user whether granularity, dependencies, splitting/merging, and AFK/HITL/Needs info classifications are right. Iterate until approved.

## Publishing workflow

Publish approved issues in dependency order so later issues can reference real blockers. Do not close or modify parent issues unless the user explicitly asks.

Before publishing, show the user the detected preflight target, labels to apply, issue count, and issue titles, then ask for explicit approval to publish. If approval is not explicit, do not create issues.

Each approved slice is one `forge publish` tracker-issue or work-item plus provider-native readback. The disclosed provider reference owns native create, labels, comments, safe-body, and fallback. Never paste secrets or sensitive payloads into issue bodies or comments. Apply mapped labels only when they exist in `<triage-labels-doc>`; otherwise record the slice type in the issue body.

For generated AFK issues, preserve the `## Agent Readiness` section from the issue body template. If any readiness field lacks durable context and no maintainer waiver exists, publish the slice as HITL or Needs info instead of applying an AFK-ready label.

## Issue body template

Use [skill://plan-to-issues/templates/issue-body.md](skill://plan-to-issues/templates/issue-body.md) as the starting point for each published issue body. Keep the AFK/HITL/Needs info type, parent reference, vertical-slice description, user stories, acceptance criteria, Agent Readiness section, out-of-scope notes, safety/evidence notes, and blocker details intact unless the approved breakdown requires a narrower value.
