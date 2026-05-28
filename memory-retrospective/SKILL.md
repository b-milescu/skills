---
name: memory-retrospective
description: >-
  Read-only claude-mem retrospective skill for memory audits, workflow
  bottleneck analysis, and aggregate reporting. Trigger when asked for memory
  retrospectives, agent usage audits, workflow bottleneck analysis, or
  claude-mem summaries.
---

# Memory Retrospective

Use when asked to mine local agent memory for process lessons, not when doing
normal repo checks.

## Triggers

- memory retrospective / memory audit
- agent usage audit
- workflow bottleneck analysis
- claude-mem aggregate reporting

## Output contract

- 1 short summary of recurring patterns.
- Aggregate counts by activity type, project, agent role, and date range when
  local DB exists.
- Bottlenecks, repeated discovery, review/CI failure patterns.
- Actionable candidate skill/template changes.
- No raw dumps.

## Read-only flow

1. Confirm question, date range, and scope.
2. Find local claude-mem DB/export; if unavailable, say so and continue with
   repo evidence only.
3. Inspect schema only enough to map the count dimensions.
4. Summarize counts, then synthesize patterns and candidate changes.
5. Stop once recommendations are actionable; do not overfit to anecdotes.

## Safety

- Never print secrets, raw prompts, credentials, auth headers, or sensitive
  payloads.
- Never paste full session dumps or unredacted examples.
- Redact or omit any example that could reconstruct private content.
- Do not upload, write back, or require claude-mem for normal repo checks.

## Candidate changes

Prefer specific follow-ups:

- skill prompt wording
- reviewer/build workflow templates
- docs pointers or check-gate clarifications
- fixture, test, or helper gaps

## If DB available

Report groupings by:

- activity type
- project
- agent role
- date range
