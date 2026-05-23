---
name: gitlab-to-issues
description: Break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues for this repo using tracer-bullet vertical slices and local triage labels. Use when the user asks for /gitlab-to-issues, GitLab issue creation, or a GitLab-specific breakdown for AFK/HITL agents; keep generic /to-issues separate.
---

# GitLab To Issues

Turn an approved plan into GitLab issues for `agents/skills` using local tracker docs and triage labels. This skill intentionally uses the distinct `gitlab-to-issues` name so it does not shadow a generic `/to-issues` skill.

## Quick start

1. Read `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` before publishing.
2. If the source is an issue, PRD, URL, or file, fetch/read its full body and comments.
3. Explore only enough context to name slices accurately: glossary terms from `CONTEXT.md` when present, relevant ADRs under `docs/adr/`, current seams, and coupling risk.
4. Draft tracer-bullet slices; ask the user to approve the breakdown before publishing.
5. Publish approved slices to GitLab using `/gitlab-local` command syntax.

## Slice rules

Each issue is a thin vertical slice through all affected user-visible layers: docs, CLI behavior, agent workflow, state, API, UI, tests, deploy/runbook, or other observable surfaces. Do not assume every project has schema/API/UI. Each slice should be demoable, reviewable, and testable on its own.

## Slice types and labels

Use only labels listed in `docs/agents/triage-labels.md`; never invent or rely on lazy label creation.

Current repo mapping:

- **AFK** → `ready-for-agent`: implementable without new human decisions. Normal review/merge policy still applies; AFK means ready for an agent, not review bypass.
- **Docs** → `docs`: documentation-only or documentation-focused slice.
- **Refactor** → `refactor`: structure-improvement slice.
- **HITL** → no live label by default: requires human decision, design review, architecture choice, product judgment, security/legal judgment, or another choice an agent must not invent. State `Type: HITL` in the issue body.
- **Needs info** → no live label by default: unclear, missing acceptance criteria, blocked by unknowns, or not safe to hand to an agent yet. State `Type: Needs info` and the blocker in the issue body.

If the label vocabulary changes, follow `docs/agents/triage-labels.md`, not these examples.

## Draft workflow

For each proposed slice, show:

- **Title**: short, domain-language title
- **Type**: AFK / HITL / Needs info
- **Blocked by**: issue title or dependency, if any
- **User stories covered**: source user stories this slice satisfies
- **Acceptance criteria**: concrete, verifiable checks
- **Coupling risk**: files/seams/safety surfaces likely to overlap other slices

Ask the user whether granularity, dependencies, splitting/merging, and AFK/HITL/Needs info classifications are right. Iterate until approved.

## Publishing workflow

Publish approved issues in dependency order so later issues can reference real blockers. Do not close or modify parent issues unless the user explicitly asks.

Use `/gitlab-local` for all `glab` command syntax, flags, comments, labels, and known pitfalls. Never paste secrets or sensitive payloads into issue bodies or comments. Apply mapped labels only when they exist in `docs/agents/triage-labels.md`; otherwise record the slice type in the issue body.

## Issue body template

```md
## Type

AFK / HITL / Needs info

## Parent

Reference to the parent issue, PRD, or source material. Omit if none.

## What to build

Concise description of the vertical slice and the user/operator-visible behavior it delivers. Describe the end-to-end outcome, not a layer-by-layer task list.

Avoid specific file paths or code snippets unless they encode a reviewed decision that prose would lose. Keep snippets small and decision-focused.

## User stories covered

- As a ..., I can ..., so that ...

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Out of scope

- Explicit adjacent work not included in this slice.

## Safety / evidence notes

- Affected surfaces: docs / CLI / agent workflow / state / migration / external integration / credentials / deploy / other.
- Expected evidence: tests, docs read/grep, dry-run, review packet notes, or other checks.
- No live PRO external mutations unless explicitly approved.

## Blocked by

None — can start immediately.

Or:

- #123 — reason this must land first.
```
