# Dev Workflows

This repo binds the shared dev workflows to GitLab through `/forge preflight`.

## Skills

- **`/forge`** — the one provider seam; every shared workflow binds through it.
- **`/gitlab`** — GitLab-specific MCP-first transport, used only by the selected GitLab branch.
- **`/issue-delivery-loop`** — coordinates bounded batches using the internal `mr-builder` and `mr-reviewer-final` routes.
- **`/plan-to-issues`**, **`/start-build`**, **`/start-review`**, **`/retro`** — each skill's own `description:` states its scope; invoke them per [Usage rules](#usage-rules).

## Skill activation mechanism

**Skill invocation** (defined in [`CONTEXT.md`](../../CONTEXT.md) glossary) means running a skill's `SKILL.md` entry procedure through the runtime skill mechanism. It is distinct from a **reference read** — reading one of a skill's reference/template files for detail after the skill is active. This section is the canonical location for the per-dialect activation mechanism mapping.

| Dialect | Declared on the agent by | Activated at runtime by | Activation verb in agent bodies/prompts |
| --- | --- | --- | --- |
| Claude (`agents/claude/*.md`) | `skills:` frontmatter field listing the skills the agent may enter. | The agent calling the `Skill` tool with the skill name. | "Invoke it via the `Skill` tool" / "invoke `<skill>` via the Skill tool". |
| OMP (`agents/omp/*.md`) | `autoload-skills:` frontmatter field. | The OMP harness auto-injecting the listed skills at session start. | "Invoke it through the OMP skill-load mechanism (its `autoload-skills` frontmatter)". |

Both dialects enter a skill at its `SKILL.md` start, not mid-policy. A launch prompt (or agent body) names the skill and instructs invocation; per the [#320 minimal-prompt exclusion rule](../../start-build/reference/parent-orchestrator.md#minimal-reviewer-launch-prompt), it must not name the skill's internal reference files, because a subagent could then satisfy the prompt with a raw reference read that skips the entry procedure. Reserve the word "load" for reference reads and other file/context loads, never for skill activation.

## Active recipes

- `skill://forge/SKILL.md` — this profile selects `skill://forge/reference/gitlab.md`.
- `skill://forge/reference/common-guard.md`
- `skill://issue-delivery-loop/SKILL.md`
- `skill://start-build/reference/parent-orchestrator.md`
- `skill://start-build/reference/parent-owned-gate.md`
- `skill://start-build/reference/post-merge-verifier.md`
- `skill://start-build/templates/delivery-schema.md`
- `skill://setup-dev-skills/reference/project-profile-facts.json`
- `skill://gitlab/SKILL.md` — selected GitLab transport branch only.

## Default MR routes

`/issue-delivery-loop` launches the shared model-free `mr-builder` basename,
resolved in the current dialect directory (`agents/claude/mr-builder.md` or
`agents/omp/mr-builder.md`). Model and effort pins live in frontmatter.

Mandatory independent review uses `mr-reviewer-final` from the same dialect
directory. A missing route remains a route-unavailable blocker; no review scout,
generic fallback, shim, old filename, or cross-runtime substitute is allowed.

## Project-profile hooks

Shared workflow records are provider-neutral: `provider`, `repository`, `issue`,
`change_request`, `commit`, and `ci`. Their identifiers and locators are opaque
outside the selected provider. This repo's profile binds them to GitLab and
declares policy hooks through
[`skill://start-build/templates/delivery-schema.md`](skill://start-build/templates/delivery-schema.md).

This repo uses the default profile from `skill://setup-dev-skills/reference/project-profile-facts.json`: repo-local policy docs stay under `docs/agents/...`, while reusable cross-project resources use explicit `skill://...` URIs.

| Project-profile field | Declaration location for this repo |
| --- | --- |
| `profile_id` / `profile_path` | `default` / this section. |
| `gate_policy_ref` | [`docs/agents/check-gate.md`](check-gate.md) exact-candidate full local gate, ready handoff, CI parity, and when-gate-cannot-run sections. |
| `label_profile_ref` | [`docs/agents/triage-labels.md`](triage-labels.md) live label inventory and agent rules. |
| `acceptance_surfaces_ref` | This doc's [Acceptance-surface vocabulary](#acceptance-surface-vocabulary) section. |
| `language_families` | Node.js/JavaScript, Bash/shell, Markdown, and YAML. |
| `branch_naming` | This doc's [Branch naming](#branch-naming) section. |
| `ci_jobs` | [`docs/agents/check-gate.md`](check-gate.md) configured advisory CI parity jobs. |
| `domain_docs` | [`docs/agents/domain.md`](domain.md) context and ADR layout. |
| `release_deploy_policy` | This doc's [Release/deploy policy](#releasedeploy-policy) section. |
| `manual_validation_rules` | [`docs/agents/check-gate.md`](check-gate.md) manual validation rules section. |
| `auxiliary_index_policy` | This doc's [Auxiliary project-index policy](#auxiliary-project-index-policy) section. |

Triage Role names map through this repo's live label vocabulary in `docs/agents/triage-labels.md`; reusable skills must read that mapping instead of assuming a global label string.

Project-profile hooks may specialize this repo's policy, but they must not
weaken the [safety-floor litany](../effort-scaling.md#hard-floors-never-scaled-away).

### Acceptance-surface vocabulary

This repo's `project_profile.acceptance_surfaces_ref` resolves here. These are
the only allowed `acceptance_surfaces` surface values for this repo; the global
evidence enum (`test`, `smoke`, `docs-read`, `ci`, `N/A — <reason>`) stays in
[`skill://start-build/templates/delivery-schema.md`](skill://start-build/templates/delivery-schema.md).

| Surface value | Meaning |
| --- | --- |
| `docs` | Documentation files changed or read as evidence. |
| `prompt` | Agent prompt / SKILL.md / agent definition file changed. |
| `agent_inventory` | Agent inventory manifest or registry changed. |
| `install_surface` | Install script, symlink, or deploy artifact changed. |
| `transport` | `/forge` selection or provider-native transport logic changed. |
| `authority` | Authority verification, approval, vote, or finish logic changed. |
| `ci_finish` | Bound CI or finish-verdict logic changed. |
| `mutation_guard` | Common guard or provider safe-body/action handling changed. |
| `tooling` | Repo-local helper, validator, test harness, or setup generation changed. |

When no surface above is touched, declare `acceptance_surfaces` as `[]`/`none`. A
declared surface without evidence, or an observably-changed surface that is not
declared, blocks ready/pass.

### Branch naming

Use issue-referencing source branches, for example `issue-<id>-<slug>`.
Provider-native source/target shapes remain inside the selected `/forge`
reference; the shared schema uses `change_request.source` and `.target`.

### Review approval / merge policy

Reviewer approval is allowed by default after a passing review unless an
explicit human/parent instruction, MR or issue note, or project rulebook section
restricts it. Use this section, or
`skill://start-review/REVIEW-FLOW.md#approval-authority-policy`, as the stable repo
policy source for `Approval authority: default-after-pass`.

Merge, auto-merge, release, deploy, close, and source-branch cleanup authority
remain separate. They require an explicit `Merge authority` value and
verifiable `Merge authority source`; approval never implies those finish
actions.

Parent-managed dev-flow finish ownership is explicit: `Finish owner: parent`. In `/issue-delivery-loop` / parent-orchestrated child-builder plus final-reviewer mode, the parent owns approval, direct merge, and auto-merge queue actions after a fresh guarded pass review; the reviewer owns only the Review Report verdict and evidence, then routes `Next action: finish-by-authorized-actor` back to the parent/authorized finisher.

### Release/deploy policy

This skills repo has no product deploy path. Release actions for skill packages
or installed skill surfaces require explicit human or workflow authority and must
cite the authority source in the MR. This release/deploy policy does not grant
merge, auto-merge, release, deploy, or operator authority by itself.

### Auxiliary project-index policy

Parent/coordinator checkouts own generated auxiliary project-index updates by default. Child worktrees treat index reports as read-only unless the project profile explicitly assigns index updates to the child. Child worktrees must not copy index artifacts between worktrees; regenerate assigned indexes in the owning checkout instead.

## Usage rules

- Invoke `/forge` before shared workflow reads or actions; this repo's verified GitLab branch then invokes `/gitlab`.
- Before converting an approved plan into tracker issues, invoke `/plan-to-issues` after `/forge preflight`.
- Before implementation, invoke `/start-build`; before independent review, invoke `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
