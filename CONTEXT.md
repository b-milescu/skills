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
The ordered seam every GitLab-backed **Dev Workflow** mutation uses before and after writing: bind project, re-read target, check reviewed SHA, exact-candidate Gate Receipt, authority, caller, text, and advisory CI attribution as relevant, choose MCP or guarded fallback, mutate once, and re-read through MCP for evidence.
_Avoid_: fallback checklist, merge guard

**Safety floor**:
A load-bearing safety/transport invariant that never scales away (for example exact-candidate local Gate Receipt, reviewed-SHA binding, explicit authority source, independent review, the child-builder and verifier boundaries, MCP-first transport correctness). Used as a shared additive leading word so a single canonical enumeration can be referenced by name ("the safety-floor litany") at non-canonical repeats instead of restating the full list. The canonical enumerations live in `docs/effort-scaling.md` (Hard floors) and the per-site "must not weaken" litany.
_Avoid_: hard limit, guard rail (when the specific invariant set is meant)

**Triage Role**:
An issue state that may be mapped to the target tracker's actual label string when that live label exists.
_Avoid_: label, status

**Skill Invocation**:
Running a skill's `SKILL.md` entry procedure through the runtime skill mechanism, so the agent enters the skill at its documented start (mode matrix, preflight, gate-ownership read, safety flow) rather than mid-policy. The per-dialect mechanism is documented in [`docs/agents/dev-workflows.md`](docs/agents/dev-workflows.md#skill-activation-mechanism): Claude uses the `skills:` agent-frontmatter field plus the Skill tool; OMP uses the `autoload-skills` frontmatter field plus harness auto-injection. A launch prompt names the skill and instructs invocation; it must not name the skill's internal reference files (the [#320 minimal-prompt exclusion rule](start-build/reference/parent-orchestrator.md#minimal-reviewer-launch-prompt)), because a subagent could then satisfy the prompt with a **Reference Read** that skips the entry procedure.
_Avoid_: load (a skill), skill-enter directive

**Reference Read**:
Reading one of a skill's reference, template, or doc files (for example `start-build/reference/child-builder.md`) for detail after the skill is already active. A **Reference Read** is legitimate context loading, but it is not a substitute for **Skill Invocation**: entering through a reference file alone skips the `SKILL.md` entry procedure. Reserve the word "load" for this kind of file/context read, never for skill activation.
_Avoid_: invoking a skill, loading a skill

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
