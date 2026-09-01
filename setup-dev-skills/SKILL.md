---
name: setup-dev-skills
description: Reconciles repo-local issue tracker, forge provider, triage, domain, Check Gate, guardrail, and workflow context for GitLab, GitHub, or Azure DevOps.
disable-model-invocation: true
---

# Setup Dev Skills

Reconcile Agent Setup Docs for tracker, triage, project profile, domain, Check Gate, coding guardrails, and dev workflows. Human-confirmed flow: explore, present findings, confirm, write.

Canonical project-profile facts live in `skill://setup-dev-skills/reference/project-profile-facts.json`. Use that file as the machine-readable source for Agent Setup Doc paths, provider/repository/default branch, tracker fields, Triage Role mapping, Check Gate refs and Dev Workflow refs, branch naming, CI parity, release/deploy policy, manual validation, domain/ADR locations, languages, runtime skill-resource URIs, and auxiliary indexes; target repo findings instantiate or override those facts.

## Invocation mode

Manual invocation only. `disable-model-invocation: true` is intentional because this Setup Skill explores target repo state, asks setup decisions, and writes Agent Setup Docs. Agents must not run it automatically.

Agents may recommend `/setup-dev-skills` when Agent Setup Docs are missing or stale, or when dev workflow skills lack repo context. Before running it or writing setup docs, ask the user for permission and then follow the decision prompts below.

## 1. Explore

Read current repo state; don't assume:

- Remote/profile facts — write a small JSON object containing `remote`, optional `profile_provider`, and optional `profile_id`, then run `node skill://setup-dev-skills/scripts/detect-provider.mjs <facts.json>`. Use only its selected provider/profile output; unknown, ambiguous, and profile/remote mismatch results stop setup instead of guessing.
- `AGENTS.md` and `CLAUDE.md` — which exists, existing `## Agent skills` block, duplicates?
- `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/adr/`, and `src/*/docs/adr/`
- `docs/agents/`, especially prior setup output and `docs/agents/check-gate.md`
- Existing coding guidance in root rulebooks, `CONTRIBUTING.md`, or `docs/agents/coding-guardrails.md`; pasted generic behavioral-guidance blocks
- Existing project-profile declarations and deviations from the fact source (see L11)
- Older setup markers: `/setup-matt-pocock-skills`, `Label in mattpocock/skills`, canonical-five label tables, lazy-label-creation prose, stale skill names
- `.scratch/` — local markdown issue tracker convention?
- Existing tracker labels when safe: `glab label list`, `gh label list`, or local docs
- Local gate clues: `Makefile`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI config, scripts, README/CONTRIBUTING commands

## 2. Ask decisions one at a time

Summarise findings first. If older setup output exists, start with an **upgrade mode** summary: legacy markers found, sections that still match evidence, sections that conflict, and recommended action. Choices: **Upgrade in place** (default), **Regenerate from live state**, or **Leave user-customised sections alone**. Preserve valid project-specific choices; reconcile stale generated guidance only.

Ask one section at a time with short explainer, choices, and recommendation.

### A — Issue tracker

Explain where work items live and which native provider tools/files to use. Use the provider/profile fact emitted by `skill://setup-dev-skills/scripts/detect-provider.mjs`; do not duplicate hostname matching here. Choices: **GitHub**, **GitLab**, **Azure DevOps**, **Local markdown**, **Other**. Local markdown and Other require an explicit user decision because the detector intentionally fails closed when there is no supported forge provider.

### B — Triage label vocabulary

Explain that `/setup-dev-skills` reconciles repo-local label docs with live tracker labels. Show both the live label list and any existing `docs/agents/triage-labels.md`, especially canonical-five output or lazy-label-creation prose, then ask which outcome to use:

1. **Document live labels as-is** — safest when a repo already has an established label workflow.
2. **Create/migrate triage-role labels** — add or rename tracker labels to match a chosen role vocabulary.
3. **Hybrid** — keep existing kind/status labels and add explicit triage-role labels only where useful.

Default: if live labels exist, document them as-is and map only roles with live labels. If no labels exist, offer the seed `skill://setup-dev-skills/triage-labels.md` vocabulary. Never rely on lazy label creation; creating, deleting, or renaming labels requires explicit user decision.

### C — Domain docs

Explain domain-aware skills read project language and ADRs. Choices: **Single-context** — root `CONTEXT.md` + `docs/adr/`; **Multi-context** — root `CONTEXT-MAP.md` points to per-context docs. Recommend from existing files; otherwise single-context.

### D — Check gate

Explain build/review skills need exact local commands before claiming ready. Recommend from Makefiles, package scripts, language project files, CI config, and docs. If no full gate exists, document best available checks plus `N/A — no full local gate discovered`; ask user to confirm.

### E — Coding guardrails

Explain these guardrails reduce common agent coding mistakes: hidden assumptions, overengineering, drive-by edits, and unverified completion. Choices: **Adopt defaults**, **Merge with existing guidance**, **Skip**, **Custom**. If existing generic guidance was pasted into a root rulebook, recommend moving it behind `docs/agents/coding-guardrails.md` while preserving project-specific additions.

### F — Project-profile hooks and dev workflows

Explain that shared workflows bind one provider through `/forge` and use opaque `issue`, `change_request`, `commit`, and `ci` records from `skill://start-build/templates/delivery-schema.md`. Record the target repo's fact-source profile (see L11). Repo policy stays repo-relative; reusable resources use `skill://...`. Auxiliary indexes default to parent-owned and read-only in child worktrees unless assigned.

Generated docs reference `/forge`, `/start-build`, `/start-review`, and `/plan-to-issues` for GitLab, GitHub, and Azure DevOps. Add `/gitlab` only for the GitLab profile. Other providers use their native `/forge` branch; never disable the shared workflows solely because the repository is not GitLab.

## 3. Confirm draft

Show before writing: `## Agent skills` plus `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md`, `check-gate.md`, `coding-guardrails.md`, and `dev-workflows.md` or target-specific paths from the fact source (see L11). For upgrades, include markers, per-section decisions, and rationale. Include the L11 fact map. Let user edit.

## 4. Write

Pick file: if `CLAUDE.md` exists, edit it; else if `AGENTS.md` exists, edit it; if neither exists, ask which one to create. Never create one when the other already exists. If `## Agent skills` exists, update it in place without touching surrounding sections; if multiple or legacy blocks exist, ask which block to keep and remove/merge duplicates only after confirmation.

Block shape. Substitute each `<agent_setup_docs.*>` placeholder from the selected `project_profile.agent_setup_docs` values in the fact source (see L11) or live target-repo findings; never copy default `docs/agents/...` paths into a repo with a non-default Agent Setup Doc root:

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

Adapt this skill's neutral seed files from live inspection using `skill://setup-dev-skills/reference/project-profile-facts.json`. Reconcile older output without overwriting user additions. Generate the neutral Dev Workflow from `skill://setup-dev-skills/dev-workflows-generic.md`; add `/gitlab` pointers only for GitLab.

Done only when the substitution rule above is satisfied and `triage-labels.md` carries no placeholder or default label unless the user chose to seed it.

## 5. Done

Tell user setup is complete; generated docs can be edited directly later. Rerun only to switch trackers or regenerate.
