# Agent Skills

This context covers reusable agent skills and the repo-local docs that let those skills operate safely inside a target project.

## Language

**Agent Skill**:
A reusable instruction package that teaches an agent a task-specific workflow.
_Avoid_: prompt, script

**Setup Skill**:
An **Agent Skill** that scaffolds repo-local guidance for other skills before they are used in a target project.
_Avoid_: installer, bootstrap script

**Agent Setup Docs**:
Repo-local guidance that tells skills where project work lives, which live tracker labels and terms to use, and which workflows are valid.
_Avoid_: generated config, settings

**Dev Workflow**:
A project workflow for planning, building, and reviewing changes through that project's tools.
_Avoid_: AI workflow

**Check Gate**:
A documented set of local commands that provides readiness evidence before review.
_Avoid_: test script, CI

**GitLab Mutation Guard**:
The ordered seam every GitLab-backed **Dev Workflow** mutation uses before and after writing: bind project, re-read target, check reviewed SHA/CI/authority/caller/text as relevant, choose MCP or guarded fallback, mutate once, and re-read through MCP for evidence.
_Avoid_: fallback checklist, merge guard

**Triage Role**:
An issue state that may be mapped to the target tracker's actual label string when that live label exists.
_Avoid_: label, status

## Relationships

- A **Setup Skill** creates **Agent Setup Docs** for a target repo.
- **Agent Setup Docs** inventory live tracker labels and map **Triage Roles** only where the project has confirmed labels for them.
- A **Dev Workflow** depends on the selected issue tracker.
- GitLab-backed **Dev Workflows** use GitLab issues and merge requests.
- A **Check Gate** records the repo-specific commands builders and reviewers use as local evidence.
- A **GitLab Mutation Guard** preserves mutation safety across MCP primary transport and guarded fallback helpers.

## Example dialogue

> **Dev:** "Should this setup skill call the section agent workflows?"
> **Domain expert:** "No — use **Dev Workflow**. The value is project workflow guidance, not branding the actor."

## Flagged ambiguities

- "Agent workflow" was rejected in favour of **Dev Workflow** for planning, build, and review guidance.
