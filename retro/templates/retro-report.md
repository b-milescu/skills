# Retro Report template

The Retro Report is the session deliverable; accepted follow-up issues are the durable record. Post or keep the report in the conversation (or a caller-provided run directory) — do not edit canonical skills/docs directly from a retro, and do not invent metric values: use `N/A — <why>` when a metric was not observable.

```markdown
# Retro Report — <scope, e.g. batch issues #204–#207 / MRs !193–!196>

<n> findings — <a> adopt / <e> experiment / <m> monitor / <h> human-decision.
Scope: <issues / MRs / session>. Date: <YYYY-MM-DD>.

## Batch metrics

| Metric | Value |
|---|---|
| Issues attempted | <n> |
| MRs opened | <n> |
| MRs merged | <n> |
| MRs queued (auto-merge) | <n> |
| MRs blocked | <n> |
| Review rounds (total / max per MR) | <n> / <n> |
| CI failures | <n> |
| Brief defects | <n> |
| Follow-up issues created | <n> |

## What went well

- <behavior worth preserving, with evidence — keep this honest, not ceremonial>

## Findings

### RF-1 — <one-line title>

- **Category:** <flow | process | context | taxonomy | tooling | docs-drift>
- **Disposition:** <adopt | experiment | monitor | human-decision>
- **Claim:** <what friction happened, or what should improve>
- **Evidence + source:** <MR/issue/report URL, command output locator, observation ID — smallest excerpt that backs the claim; never secrets>
- **Owner doc:** <the canonical doc/skill that owns the behavior>
- **Proposal:** <bounded change; for human-decision, the question to escalate instead of a fix>
- **Expected effect:** <what gets better and for whom>
- **Metric to watch:** <how the next retro can tell whether it worked>

### RF-2 — <...>

## Safety floor check

<Confirm no proposal weakens any hard floor in
[Effort Scaling](skill://retro/docs/effort-scaling.md) (the canonical floor
list). List any finding reclassified to human-decision by this check, or state
"none touched".>

## Routing plan

| RF | Disposition | Route |
|---|---|---|
| RF-1 | adopt | `/gitlab-to-issues` — <target repo> issue with <labels> |
| RF-2 | monitor | next retro |
```

## Filling guidance

- **Summary first.** The finding counts and scope line lead the report so a maintainer can triage it without reading every finding.
- **One root cause per `RF-N`.** Merge symptoms that share a cause; split findings that need different owners or routes.
- **Evidence is mandatory.** A finding with no citable evidence is not a finding; either gather the evidence or drop it.
- **Stable IDs.** Number `RF-N` in report order and keep IDs stable when follow-up issues cite them.
- **Metrics are claims.** Copy batch metrics from the delivery run's report when one exists; recompute from GitLab evidence only when missing, and say which you did.
