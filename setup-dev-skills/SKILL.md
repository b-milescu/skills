---
name: setup-dev-skills
description: Reconciles repo-local issue tracker, forge provider, triage, domain, Check Gate, guardrail, and workflow context for GitLab, GitHub, or Azure DevOps.
disable-model-invocation: true
---

# Setup Dev Skills

Reconcile Agent Setup Docs for tracker, triage, project profile, domain, Check Gate, coding guardrails, and dev workflows. Human-confirmed flow: explore, present findings, confirm, write.

## Fact source

`skill://setup-dev-skills/reference/project-profile-facts.json` is the machine-readable source for Agent Setup Doc paths, provider/repository/default branch, tracker fields, Triage Role mapping, Check Gate refs and Dev Workflow refs, branch naming, CI parity, release/deploy policy, manual validation, domain/ADR locations, languages, runtime skill-resource URIs, and auxiliary indexes. Target repo findings instantiate or override those facts.

## Invocation mode

Manual invocation only. `disable-model-invocation: true` is intentional: this Setup Skill explores target repo state, asks setup decisions, and writes Agent Setup Docs.

Agents may recommend `/setup-dev-skills` when Agent Setup Docs are missing or stale, or when dev workflow skills lack repo context. Before running it or writing setup docs, ask the user for permission, then follow the decision prompts below.

## 1. Explore

Read current repo state; don't assume:

- Remote/profile facts — write a JSON object with `remote`, optional `profile_provider`, optional `profile_id`, then run `node skill://setup-dev-skills/scripts/detect-provider.mjs <facts.json>`. Use only its selected provider/profile output; unknown, ambiguous, and profile/remote mismatch results stop setup instead of guessing.
- `AGENTS.md` and `CLAUDE.md` — which exists, existing `## Agent skills` block, duplicates?
- `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/adr/`, `src/*/docs/adr/`
- `docs/agents/`, especially prior setup output and `docs/agents/check-gate.md`
- Coding guidance in root rulebooks, `CONTRIBUTING.md`, or `docs/agents/coding-guardrails.md`; pasted generic behavioral-guidance blocks
- Project-profile declarations and deviations from the [fact source](#fact-source)
- `.scratch/` — local markdown tracker convention?
- Tracker labels when safe: `glab label list`, `gh label list`, or local docs
- Local gate clues: `Makefile`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI config, scripts, README/CONTRIBUTING commands

## 2. Ask decisions one at a time

Summarise findings first. With prior setup output, open with an **upgrade mode** summary: which sections still match evidence, which conflict, recommended action. Choices: **Upgrade in place** (default), **Regenerate from live state**, **Leave user-customised sections alone**. Preserve valid project-specific choices; reconcile stale generated guidance only.

Then ask one section at a time with short explainer, choices, recommendation.

### A — Issue tracker

Where work items live and which native provider tools/files to use. Take the provider/profile fact from `skill://setup-dev-skills/scripts/detect-provider.mjs`; do not duplicate hostname matching here. Choices: **GitHub**, **GitLab**, **Azure DevOps**, **Local markdown**, **Other**. The last two need an explicit user decision because the detector fails closed without a supported forge provider.

### B — Triage label vocabulary

Show the live label list beside any existing `docs/agents/triage-labels.md`, then ask:

1. **Document live labels as-is** — safest where a label workflow is established.
2. **Create/migrate triage-role labels** — add or rename tracker labels to a chosen role vocabulary.
3. **Hybrid** — keep existing kind/status labels, add triage-role labels only where useful.

Default: with live labels, document them as-is and map only roles that have one; otherwise offer the seed `skill://setup-dev-skills/triage-labels.md` vocabulary. Never rely on lazy label creation; creating, deleting, or renaming labels requires explicit user decision.

### C — Domain docs

Domain-aware skills read project language and ADRs. Choices: **Single-context** — root `CONTEXT.md` + `docs/adr/`; **Multi-context** — root `CONTEXT-MAP.md` pointing at per-context docs. Recommend from existing files; otherwise single-context.

### D — Check gate

Build/review skills need exact local commands for the sole required exact-candidate quality gate; provider CI is advisory evidence that never replaces or blocks it. Recommend commands from Makefiles, package scripts, language project files, CI config, docs. With no full gate, document the best available checks plus `N/A — no full local gate discovered` and ask the user to confirm.

### E — Coding guardrails

These guardrails reduce common agent coding mistakes: hidden assumptions, overengineering, drive-by edits, unverified completion. Choices: **Adopt defaults**, **Merge with existing guidance**, **Skip**, **Custom**. Where generic guidance was pasted into a root rulebook, recommend moving it behind `docs/agents/coding-guardrails.md` while preserving project-specific additions.

### F — Project-profile hooks and dev workflows

Shared workflows bind one provider through `/forge` and use opaque `issue`, `change_request`, `commit`, and `ci` records from `skill://start-build/templates/delivery-schema.md`. Record the target repo's profile from the [fact source](#fact-source). Repo policy stays repo-relative; reusable resources use `skill://...`. Auxiliary indexes default to parent-owned and read-only in child worktrees unless assigned.

Generated docs reference `/forge`, `/start-build`, `/start-review`, and `/plan-to-issues` for GitLab, GitHub, and Azure DevOps. Add `/gitlab` only for the GitLab profile. Other providers use their native `/forge` branch; never disable the shared workflows solely because the repository is not GitLab.

## 3. Confirm draft

Show before writing: the `## Agent skills` block, the fact map, and `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md`, `check-gate.md`, `coding-guardrails.md`, `dev-workflows.md` — or the target-specific paths from the [fact source](#fact-source). For upgrades, include per-section decisions and rationale. Let user edit.

## 4. Write

Pick file: if `CLAUDE.md` exists, edit it; else if `AGENTS.md` exists, edit it; if neither exists, ask which to create. Never create one when the other exists. Update an existing `## Agent skills` block in place without touching surrounding sections; with multiple or legacy blocks, ask which to keep and merge or remove duplicates only after confirmation.

Substitute each `<agent_setup_docs.*>` placeholder below from the selected `project_profile.agent_setup_docs` values in the [fact source](#fact-source) or live findings; never copy default `docs/agents/...` paths into a repo with a non-default Agent Setup Doc root:

```md
## Agent skills
### Issue tracker
[summary]. See `<agent_setup_docs.issue_tracker>`.
### Triage labels
[summary]. See `<agent_setup_docs.triage_labels>`.
### Domain docs
[summary]. See `<agent_setup_docs.domain>`.
### Check gate
[summary]. See `<agent_setup_docs.check_gate>`.
### Coding guardrails
[summary]. See `<agent_setup_docs.coding_guardrails>`.
### Dev workflows
[summary]. See `<agent_setup_docs.dev_workflows>`.
```

Adapt this skill's neutral seed files from live inspection using the [fact source](#fact-source), reconciling older output without overwriting user additions. Generate the neutral Dev Workflow from `skill://setup-dev-skills/dev-workflows-generic.md`; add `/gitlab` pointers only for GitLab.

Done only when that substitution rule is satisfied and `triage-labels.md` carries no placeholder or default label unless the user chose to seed it.
