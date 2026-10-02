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

**Mutation Guard**:
The ordered evidence and authority boundary a **Dev Workflow** crosses before and after one mutation in its confirmed integration.
_Avoid_: fallback checklist, merge guard

**Safety floor**:
A load-bearing safety/transport invariant that never scales away. Used as a shared additive leading word so the canonical enumeration can be referenced by name ("the safety-floor litany"); it lives in `docs/effort-scaling.md` (Hard floors).
_Avoid_: hard limit, guard rail (when the specific invariant set is meant)

**Triage Role**:
An issue state that may be mapped to the target tracker's actual label string when that live label exists.
_Avoid_: label, status

**Skill Invocation**:
Entering a skill at its `SKILL.md` entry procedure through the runtime skill mechanism, rather than mid-policy. The per-dialect mechanism is owned by [dev-workflows](docs/agents/dev-workflows.md#skill-activation-mechanism).
_Avoid_: load (a skill), skill-enter directive

**Reference Read**:
Reading a skill's reference, template, or doc file after the skill is active. Legitimate context loading, never a substitute for **Skill Invocation**. See [dev-workflows](docs/agents/dev-workflows.md#skill-activation-mechanism).
_Avoid_: invoking a skill, loading a skill

## Flagged ambiguities

- "Agent workflow" was rejected in favour of **Dev Workflow** for planning, build, and review guidance.
