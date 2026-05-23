---
name: setup-dev-skills
description: Sets up an `## Agent skills` block in AGENTS.md/CLAUDE.md and repo-local docs so dev skills know the issue tracker, triage labels, domain docs, check gate, and workflow skill references. Use before first use of `gitlab-local`, `gitlab-to-issues`, `start-build`, or `start-review` in a new repo, or when those skills lack repo context.
disable-model-invocation: true
---

# Setup Dev Skills

Scaffold repo-local configuration for this skill pack: issue tracker, triage labels, domain docs, check gate, and dev workflows. Prompt-driven: explore, present findings, confirm with user, then write.

## 1. Explore

Read current repo state; don't assume:

- `git remote -v` and `.git/config` — GitHub, GitLab, self-hosted, none?
- `AGENTS.md` and `CLAUDE.md` — which exists, and any existing `## Agent skills` block?
- `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/adr/`, and `src/*/docs/adr/`
- `docs/agents/` and `docs/agents/check-gate.md` — prior output?
- `.scratch/` — local markdown issue tracker convention?
- Existing tracker labels when safe: `glab label list`, `gh label list`, or local docs.
- Local gate clues: `Makefile`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI config, scripts, README/CONTRIBUTING commands.

## 2. Ask decisions one at a time

Summarise findings first. Then ask one section at a time with a short explainer, choices, and recommendation.

### A — Issue tracker

Explain where issues/PRDs live and which CLI/files to use. Recommend by remote: GitLab → **GitLab**; GitHub → **GitHub**; no remote but `.scratch/` exists → **Local markdown**; otherwise ask. Choices: **GitHub**, **GitLab**, **Local markdown**, **Other**. For Other, record workflow prose.

### B — Triage label vocabulary

Explain that `/setup-dev-skills` reconciles repo-local label docs with the tracker's live labels. Show both the live label list and any existing `docs/agents/triage-labels.md`, then ask which outcome to use:

1. **Document live labels as-is** — safest when a repo already has an established label workflow.
2. **Create/migrate triage-role labels** — add or rename tracker labels to match a chosen role vocabulary.
3. **Hybrid** — keep existing kind/status labels and add explicit triage-role labels only where useful.

Default recommendation: if live labels exist, document the live labels as-is and map only roles that already have a live label. If the tracker has no labels, offer the common starting role vocabulary from the seed `triage-labels.md`. Never rely on lazy label creation; creating, deleting, or renaming labels requires an explicit user decision.

### C — Domain docs

Explain domain-aware skills read project language and ADRs. Choices: **Single-context** — root `CONTEXT.md` + `docs/adr/`; **Multi-context** — root `CONTEXT-MAP.md` points to per-context docs. Recommend from existing files; otherwise single-context.

### D — Check gate

Explain build/review skills need exact local commands before claiming ready. Recommend from Makefiles, package scripts, language project files, CI config, and docs. If no full gate exists, document best available checks plus `N/A — no full local gate discovered`; ask user to confirm.

### E — Dev workflows

Explain generated docs should tell future agents which workflow skill to load. If tracker is GitLab, reference `/gitlab-local`, `/gitlab-to-issues`, `/start-build`, and `/start-review`. Otherwise list them as GitLab-only and direct agents to generic `/to-issues` or tracker-specific workflow.

## 3. Confirm draft

Show draft contents before writing: `## Agent skills` block plus `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md`, `check-gate.md`, and `dev-workflows.md`. If existing docs disagree with live tracker labels, include the chosen reconciliation outcome and rationale. Let user edit.

## 4. Write

Pick file: if `CLAUDE.md` exists, edit it; else if `AGENTS.md` exists, edit it; if neither exists, ask which one to create. Never create one when the other already exists. If `## Agent skills` exists, update it in place without touching surrounding sections.

Block shape:

```md
## Agent skills

### Issue tracker

[summary]. See `docs/agents/issue-tracker.md`.

### Triage labels

[summary]. See `docs/agents/triage-labels.md`.

### Domain docs

[summary]. See `docs/agents/domain.md`.

### Check gate

[summary]. See `docs/agents/check-gate.md`.

### Dev workflows

[summary]. See `docs/agents/dev-workflows.md`.
```

Use seed files in this skill folder for docs. Adapt host/project names, live tracker labels, and local gate commands from repo inspection. Do not leave default or placeholder labels in `triage-labels.md` unless the user explicitly chose to create/migrate to them. Use `dev-workflows-gitlab.md` for GitLab and `dev-workflows-generic.md` otherwise.

## 5. Done

Tell user setup is complete. Mention generated docs can be edited directly later; rerun only to switch trackers or regenerate.
