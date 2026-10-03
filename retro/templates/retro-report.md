# Retro Report template

The Retro Report is the session deliverable; accepted follow-up issues are the durable record. Post or keep the report in the conversation (or a caller-provided run directory) — do not edit canonical skills/docs directly from a retro, and do not invent metric values: use `N/A — <why>` when a metric was not observable. Copy batch metrics from the delivery run's report when one exists, recompute from tracker evidence only when it does not, and say which you did.

A report is complete only after independent refutation assigns every finding a verdict, each survivor includes its strongest counter-argument and response, and the report carries the refuter's safety-floor attestation ([reference/refutation.md](../reference/refutation.md)). A zero-finding report still requires the refuter's report-level check and attestation. Unavailable evidence and metrics may be `N/A — <why>`; unavailable refutation leaves an explicitly unrefuted draft, not a final report. Only the refuted report reaches the user; counts, findings, and the safety floor check below are all post-verdict.

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
| RF-3 | drop | <which cited evidence failed> |

## Safety floor check

<Refuter's attestation: no surviving proposal weakens any floor in
[Start Build Safety floors](skill://start-build/SAFETY.md#safety-floors).
List any finding escalated to human-decision by this check, or state
"none touched".>

## Routing plan

| RF | Disposition | Route |
|---|---|---|
| RF-1 | adopt | `/plan-to-issues` — <target repo> issue with <labels> |
| RF-2 | monitor | next retro |
```
