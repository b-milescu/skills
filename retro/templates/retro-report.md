# Retro Report template

The Retro Report is the session deliverable; accepted follow-up issues are the durable record. Post or keep the report in the conversation (or a caller-provided run directory) — do not edit canonical skills/docs directly from a retro, and do not invent metric values: use `N/A — <why>` when a metric was not observable.

The report reaches the user only after the refuter pass ([reference/refutation.md](../reference/refutation.md)): counts, findings, and the safety floor check below are all post-verdict.

```markdown
# Retro Report — <scope, e.g. batch issues #204–#207 / change requests !193–!196>

<n> findings after refutation — <a> adopt / <e> experiment / <m> monitor / <h> human-decision.
<d> dropped, <x> merged, <r> rerouted by the refuter.
Scope: <issues / change requests / session>. Date: <YYYY-MM-DD>.

## Batch metrics

| Metric | Value |
|---|---|
| Issues attempted | <n> |
| change requests opened | <n> |
| change requests merged | <n> |
| change requests queued (auto-merge) | <n> |
| change requests blocked | <n> |
| Review rounds (total / max per change request) | <n> / <n> |
| CI failures | <n> |
| Brief defects | <n> |
| Follow-up issues created | <n> |
| **`other` tokens used** — evidence sources, counting and N/A rules: [delivery-loop Metrics](skill://issue-delivery-loop/SKILL.md#metrics) | `action_blocker`: <n> / <total> or N/A — <why>; `blocker_token`: <n> / <total> or N/A — <why>; `not_run_reason`: <n> / <total> or N/A — <why> |

## What went well

- <behavior worth preserving, with evidence — keep this honest, not ceremonial>

## Findings

### RF-1 — <one-line title>

- **Category:** <flow | process | context | taxonomy | tooling | docs-drift>
- **Disposition:** <adopt | experiment | monitor | human-decision>
- **Claim:** <observed friction; distinguish established cause from unresolved attribution>
- **Evidence + source:** <change request/issue/report URL, command output locator, observation ID — smallest safe excerpt; state unavailable evidence and uncertain local-source/running-server correspondence>
- **Owner:** <evidenced implementation, configuration, documentation, or skill owner with repository and component/file locator; unknown when unresolved>
- **Proposal:** <bounded change supported by causal evidence; for monitor, what evidence to watch for; for human-decision, the question to escalate instead of a fix>
- **Expected effect:** <what gets better and for whom>
- **Metric to watch:** <how the next retro can tell whether it worked>
- **Refutation:** <the strongest counter-argument the refuter raised, and why this finding survives it>

### RF-2 — <...>

## Refutation log

| RF | Verdict | Why |
|---|---|---|
| RF-1 | survives | <counter-argument raised and why it lost> |
| RF-3 | dropped | <which cited evidence failed> |

## Safety floor check

<Refuter's attestation: no surviving proposal weakens any hard floor in
[Effort Scaling](skill://retro/docs/effort-scaling.md) (the canonical floor
list). List any finding escalated to human-decision by this check, or state
"none touched".>

## Routing plan

| RF | Disposition | Route |
|---|---|---|
| RF-1 | adopt | `/plan-to-issues` — <target repo> issue with <labels> |
| RF-2 | monitor | next retro |
```

## Filling guidance

- **Summary first.** The finding counts and scope line lead the report so a maintainer can triage it without reading every finding.
- **One root cause per `RF-N`.** Merge symptoms that share a cause; split findings that need different owners or routes.
- **Evidence is mandatory.** A finding with no citable evidence is not a finding; either gather the evidence or drop it.
- **Attribution and Owner.** Follow [ownership guidance](../reference/signal-catalogue.md#ownership-mapping-hints): observed friction can survive as `monitor` without a proven cause or forced Owner. Evidence collection stays within [SKILL.md](../SKILL.md)'s session-first and privacy bounds.
- **Survivors carry their counter-argument.** Every finding the user reads has already been argued against; the `Refutation` field shows the argument it beat, so triage sees both sides.
- **Dropped findings stay visible.** Log every dropped and merged `RF-N` with the reason so the next retro does not re-raise it.
- **Stable IDs.** Number `RF-N` in report order and keep IDs stable when follow-up issues cite them.
- **Metrics are claims.** Copy batch metrics from the delivery run's report when one exists; recompute from tracker evidence only when missing, and say which you did.
