# Dev Workflows

This repo binds the shared dev workflows to GitLab through `/forge preflight`.

## Skills

- **`/forge`** — the one provider seam; every shared workflow binds through it.
- **`/issue-delivery-loop`** — coordinates bounded batches using the internal `mr-builder` and `mr-reviewer-final` routes.
- **`/plan-to-issues`**, **`/start-build`**, **`/start-review`**, **`/retro`** — each skill's own `description:` states its scope; invoke them per [Usage rules](#usage-rules).

## Skill activation mechanism

**Skill invocation** (defined in [`CONTEXT.md`](../../CONTEXT.md) glossary) means running a skill's `SKILL.md` entry procedure through the runtime skill mechanism. It is distinct from a **reference read** — reading one of a skill's reference/template files for detail after the skill is active. This section is the canonical location for the per-dialect activation mechanism mapping.

| Dialect | Declared on the agent by | Activated at runtime by | Activation verb in agent bodies/prompts |
| --- | --- | --- | --- |
| Claude (`agents/claude/*.md`) | `skills:` frontmatter preloads bodies; it is not an invocation allowlist. | Invoke additional eligible installed skills via the `Skill` tool at their entry. | "Invoke it via the `Skill` tool" / "invoke `<skill>` via the Skill tool". |
| OMP (`agents/*.md`, excluding README) | `autoload-skills:` frontmatter preloads bodies at session start, separately from inherited discovery inventory. | The OMP skill-load mechanism enters preloads; eligible unpreloaded entries remain available through runtime entry resolution (`skill://<name>`). | "Invoke it through the OMP skill-load mechanism (its `autoload-skills` frontmatter)" for preloads; "invoke its entry through the OMP skill-load mechanism" on demand. |

Both dialects enter a skill at its `SKILL.md` start, not mid-policy. A launch prompt (or agent body) names the skill and instructs invocation; per the [#320 minimal-prompt exclusion rule](../../start-build/reference/parent-orchestrator.md#minimal-reviewer-launch-prompt), it must not name the skill's internal reference files, because a subagent could then satisfy the prompt with a raw reference read that skips the entry procedure. Reserve the word "load" for reference reads and other file/context loads, never for skill activation.

Preload, discovery eligibility, Skill Invocation and Reference Read are distinct:
an available/resolvable entry is not invocation permission. Check authoritative
frontmatter for user-only restrictions before on-demand entry invocation.
Dev Workflow entries use the shared
[Task-selected specialists](../../start-build/reference/context-and-planning.md#task-selected-specialists)
policy; coordinators leave that choice to each actor.

## Active recipes

- `skill://forge/SKILL.md` — this target selects [native-integration.md](native-integration.md).
- `skill://forge/reference/common-guard.md`
- `skill://issue-delivery-loop/SKILL.md`
- `skill://start-build/reference/parent-orchestrator.md`
- `skill://start-build/reference/parent-owned-gate.md`
- `skill://start-build/reference/post-merge-verifier.md`
- `skill://start-build/templates/delivery-schema.md`
- `skill://setup-dev-skills/reference/project-profile-facts.json`

## Default MR routes

`/issue-delivery-loop` launches `mr-builder` and independent `mr-reviewer-final`
using the active runtime's effective same-name project declarations when present,
otherwise provider-neutral shared routes. Follow the existing
[native model and effort selection](../../start-build/reference/parent-orchestrator.md#native-model-and-effort-selection)
contract; complete declarations do not force model/effort overrides.

Mandatory independent review uses `mr-reviewer-final` from the same dialect
directory. A missing route remains a route-unavailable blocker; no review scout,
generic fallback, shim, old filename, or cross-runtime substitute is allowed.

## Project-profile hooks

Shared workflow records are provider-neutral: `provider`, `repository`, `issue`,
`change_request`, `commit`, and `ci`. Their identifiers and locators are opaque
outside the selected provider. This repo's profile binds them to GitLab and
declares policy hooks through
[`skill://start-build/templates/delivery-schema.md`](skill://start-build/templates/delivery-schema.md).

This repo's confirmed profile is declared here, not in installed shared facts.
`provider.reference: docs/agents/native-integration.md` resolves from the invoked
target clone. Code/work-item/CI scopes are this repository's GitLab instance and
agents/skills repository, verified through that document's native preflight.
Installed `docs/` aliases retain this source ownership and expose native facts;
they never supply foreign targets with defaults.

Confirmed project declaration (owned by this target, not shared field guidance):

```yaml
project_profile:
  profile_id: agents-skills
  profile_path: docs/agents/dev-workflows.md#project-profile-hooks
  provider:
    name: gitlab-nja
    reference: docs/agents/native-integration.md
  tracker:
    scope: https://gitlab.example.com/agents/skills
    reference: docs/agents/issue-tracker.md
  agent_setup_docs:
    root: docs/agents
    issue_tracker: docs/agents/issue-tracker.md
    triage_labels: docs/agents/triage-labels.md
    domain: docs/agents/domain.md
    check_gate: docs/agents/check-gate.md
    coding_guardrails: docs/agents/coding-guardrails.md
    dev_workflows: docs/agents/dev-workflows.md
  label_profile_ref: docs/agents/triage-labels.md
  label_vocabulary:
    reference: docs/agents/triage-labels.md
  gate_policy_ref: docs/agents/check-gate.md#full-local-gate
  check_gate:
    command: npm run check
    runtime: Node.js 22.x
    bootstrap: npm ci
  dev_workflows:
    reference: docs/agents/dev-workflows.md
  acceptance_surfaces_ref: docs/agents/dev-workflows.md#acceptance-surface-vocabulary
  language_families: [javascript, shell, markdown, yaml]
  branch_naming:
    pattern: issue-<id>-<slug>
  ci_parity:
    reference: docs/agents/check-gate.md#ci-parity
  domain_docs:
    reference: docs/agents/domain.md
  release_deploy_policy:
    reference: docs/agents/dev-workflows.md#releasedeploy-policy
  manual_validation_rules:
    reference: docs/agents/check-gate.md#manual-validation-rules
  auxiliary_index_policy:
    owner: parent
    child_worktree_mode: read-only-unless-assigned
    copy_between_worktrees: forbidden
  skill_resources:
    forge: skill://forge/SKILL.md
    builder: skill://start-build/SKILL.md
    reviewer: skill://start-review/SKILL.md
  resource_addressing:
    target_repo_docs: repo-relative
    runtime_skill_resources: skill-uri
```

### Runtime project declarations and provenance

Shared installed routes are provider-neutral. This repository's complete
same-name declarations live in `.claude/agents/` and `.omp/agents/`, retaining
canonical entries, builder/reviewer bounds, model/effort neutrality and task-selected
specialists; only these target-owned files name confirmed native servers.

OMP's installed discovery selects nearest project `.omp/agents` before user
`~/.omp/agent/agents`, then extension/plugin/bundled entries. Establish this from
the actual installed loader using `tests/omp-agent-loader-smoke.sh`, not by
assuming Claude's precedence. Claude documents managed/CLI definitions ahead of
nearest project `.claude/agents`, then user and plugin definitions; verify the
actual effective selection in a fresh Claude spawning session independently.
See [Claude subagents](https://code.claude.com/docs/en/subagents.md).

Launch/relaunch the **spawning session** from the intended checkout. Changing a
child's execution CWD does not reselect a cached route. Independently invoke
allocated and revision checkout sessions; record selected file/source and exact
canonical skill-entry provenance separately from entry access, available tools
and live model behavior. A readable file or intended frontmatter proves neither
actual selection nor hard MCP confinement; OMP inherited tool proxies are a
distinct runtime property. No external runtime patch or generic MCP wildcard is
part of this declaration.

| Project-profile field | Declaration location for this repo |
| --- | --- |
| `profile_id` / `profile_path` | `agents-skills` / `docs/agents/dev-workflows.md#project-profile-hooks`. |
| `gate_policy_ref` | [`docs/agents/check-gate.md`](check-gate.md) exact-candidate full local gate, ready handoff, CI parity, and when-gate-cannot-run sections. |
| `label_profile_ref` | [`docs/agents/triage-labels.md`](triage-labels.md) live label inventory and agent rules. |
| `acceptance_surfaces_ref` | This doc's [Acceptance-surface vocabulary](#acceptance-surface-vocabulary) section. |
| `language_families` | Node.js/JavaScript, Bash/shell, Markdown, and YAML. |
| `branch_naming` | This doc's [Branch naming](#branch-naming) section. |
| `ci_parity.reference` | [`docs/agents/check-gate.md`](check-gate.md#ci-parity) configured advisory CI parity jobs. |
| `domain_docs` | [`docs/agents/domain.md`](domain.md) context and ADR layout. |
| `release_deploy_policy` | This doc's [Release/deploy policy](#releasedeploy-policy) section. |
| `manual_validation_rules` | [`docs/agents/check-gate.md`](check-gate.md) manual validation rules section. |
| `auxiliary_index_policy` | This doc's [Auxiliary project-index policy](#auxiliary-project-index-policy) section. |

Triage Role names map through this repo's live label vocabulary in `docs/agents/triage-labels.md`; reusable skills must read that mapping instead of assuming a global label string.

Project-profile hooks may specialize this repo's policy, but they must not
weaken the [safety-floor litany](../../start-build/SAFETY.md#safety-floors).

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
| `install_surface` | Native marketplace/plugin discovery, installed resources/dependencies or deploy artifact changed. |
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

- Invoke `/forge` before shared workflow reads or actions; this target's confirmed integration is [native-integration.md](native-integration.md).
- Before converting an approved plan into tracker issues, invoke `/plan-to-issues` after `/forge preflight`.
- Before implementation, invoke `/start-build`; before independent review, invoke `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
