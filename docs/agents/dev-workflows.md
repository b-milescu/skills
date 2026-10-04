# Dev Workflows

This repo binds the shared dev workflows to GitHub through the `forge` skill's `preflight` operation.

## Skills

- **`forge`** — the one provider seam; every shared workflow binds through it.
- **`issue-delivery-loop`** — coordinates bounded batches using the internal `change-builder` and `change-reviewer-final` routes.
- **`plan-to-issues`**, **`start-build`**, **`start-review`**, **`retro`** — each skill's own `description:` states its scope; invoke them per [Usage rules](#usage-rules).

## Skill activation mechanism

**Skill invocation** (defined in the [`CONTEXT.md`](../../CONTEXT.md) glossary) means running a skill's `SKILL.md` entry procedure through the runtime skill mechanism. It is distinct from a **reference read** — reading one of a skill's reference/template files for detail after the skill is active. The per-runtime mechanism (skill ids, preload declaration, activation verbs, resource paths) is owned by [agents/README.md](../../agents/README.md#skill-invocation-and-resource-paths).

A launch prompt (or agent body) names the skill and instructs invocation; per the [minimal-prompt exclusion rule](../../start-build/reference/parent-orchestrator.md#minimal-reviewer-launch-prompt), it must not name the skill's internal reference files, because a subagent could then satisfy the prompt with a raw reference read that skips the entry procedure. Dev Workflow entries use the shared [Task-selected specialists](../../start-build/reference/context-and-planning.md#task-selected-specialists) policy; coordinators leave that choice to each actor.

## Active recipes

- [`forge/SKILL.md`](../../forge/SKILL.md) — this target selects [native-integration.md](native-integration.md).
- [`forge/reference/common-guard.md`](../../forge/reference/common-guard.md)
- [`issue-delivery-loop/SKILL.md`](../../issue-delivery-loop/SKILL.md)
- [`start-build/reference/parent-orchestrator.md`](../../start-build/reference/parent-orchestrator.md)
- [`start-build/reference/parent-owned-gate.md`](../../start-build/reference/parent-owned-gate.md)
- [`start-build/reference/post-merge-verifier.md`](../../start-build/reference/post-merge-verifier.md)
- [`start-build/templates/delivery-schema.md`](../../start-build/templates/delivery-schema.md)
- [`setup-dev-skills/reference/project-profile-facts.json`](../../setup-dev-skills/reference/project-profile-facts.json)

## Default PR routes

The `issue-delivery-loop` skill launches `change-builder` and independent `change-reviewer-final`
using the active runtime's effective same-name project declarations when present,
otherwise provider-neutral shared routes; per-runtime route ids are in
[agents/README.md](../../agents/README.md#route-ids). Follow the existing
[native model and effort selection](../../start-build/reference/parent-orchestrator.md#native-model-and-effort-selection)
contract; complete declarations do not force model/effort overrides.

Mandatory independent review uses `change-reviewer-final` from the same dialect
directory. A missing route remains a route-unavailable blocker; no review scout,
generic fallback, shim, old filename, or cross-runtime substitute is allowed.

## Project-profile hooks

Shared workflow records are provider-neutral: `provider`, `repository`, `issue`,
`change_request`, `commit`, and `ci`. Their identifiers and locators are opaque
outside the selected provider. This repo's profile binds them to GitHub and
declares policy hooks through
[`start-build/templates/delivery-schema.md`](../../start-build/templates/delivery-schema.md).

This repo's confirmed profile is declared here, not in installed shared facts.
`provider.reference: docs/agents/native-integration.md` resolves from the invoked
target clone. Code/work-item/CI scopes are this repository's GitHub repository
`b-milescu/skills`, verified through that document's native preflight.

Confirmed project declaration (owned by this target, not shared field guidance):

```yaml
project_profile:
  profile_id: agents-skills
  profile_path: docs/agents/dev-workflows.md#project-profile-hooks
  provider:
    name: github
    reference: docs/agents/native-integration.md
  tracker:
    scope: https://github.com/b-milescu/skills
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
    command: bun run check
    runtime: Bun 1.4+
    bootstrap: bun install --frozen-lockfile
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
    forge: forge/SKILL.md
    builder: start-build/SKILL.md
    reviewer: start-review/SKILL.md
  resource_addressing:
    target_repo_docs: repo-relative
    runtime_skill_resources: skill-qualified
```

### Runtime project declarations and provenance

Shared installed routes are provider-neutral. This repository's complete
same-name declarations live in `.claude/agents/` and `.omp/agents/`. Like the
shared routes they declare no `tools` and inherit all of the parent session's
tools, and they reach GitHub through the parent's github MCP server or `gh`. Route
ids, runtime precedence, provenance and what to validate and observe separately
are owned by
[agents/README.md](../../agents/README.md#runtime-specific-precedence); the OMP
loader proof is `tests/omp-agent-loader-smoke.sh`.

| Project-profile field | Declaration location for this repo |
| --- | --- |
| `profile_id` / `profile_path` | `agents-skills` / `docs/agents/dev-workflows.md#project-profile-hooks`. |
| `gate_policy_ref` | [`docs/agents/check-gate.md`](check-gate.md) exact-candidate full local gate, ready handoff, CI parity, and when-gate-cannot-run sections. |
| `label_profile_ref` | [`docs/agents/triage-labels.md`](triage-labels.md) live label inventory and agent rules. |
| `acceptance_surfaces_ref` | This doc's [Acceptance-surface vocabulary](#acceptance-surface-vocabulary) section. |
| `language_families` | JavaScript (Bun), Bash/shell, Markdown, and YAML. |
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
[`start-build/templates/delivery-schema.md`](../../start-build/templates/delivery-schema.md).

| Surface value | Meaning |
| --- | --- |
| `docs` | Documentation files changed or read as evidence. |
| `prompt` | Agent prompt / SKILL.md / agent definition file changed. |
| `agent_inventory` | Agent inventory manifest or registry changed. |
| `install_surface` | Native marketplace/plugin discovery, installed resources/dependencies or deploy artifact changed. |
| `transport` | The `forge` skill's selection or provider-native transport logic changed. |
| `authority` | Authority verification, approval, vote, or finish logic changed. |
| `ci_finish` | Bound CI or finish-verdict logic changed. |
| `mutation_guard` | Common guard or provider safe-body/action handling changed. |
| `tooling` | Repo-local helper, validator, test harness, or setup generation changed. |

When no surface above is touched, declare `acceptance_surfaces` as `[]`/`none`. A
declared surface without evidence, or an observably-changed surface that is not
declared, blocks ready/pass.

### Branch naming

Use issue-referencing source branches, for example `issue-<id>-<slug>`.
Provider-native source/target shapes remain inside the selected provider
reference; the shared schema uses `change_request.source` and `.target`.

### Review approval / merge policy

Reviewer approval is allowed by default after a passing review unless an
explicit human/parent instruction, PR or issue comment, or project rulebook section
restricts it. Use this section, or
[`start-review/REVIEW-FLOW.md#approval-authority-policy`](../../start-review/REVIEW-FLOW.md#approval-authority-policy),
as the stable repo policy source for `Approval authority: default-after-pass`.

On GitHub the PR author cannot approve its own PR and every role here acts as one
account, so native approval is unavailable;
[native integration](native-integration.md#ready-approval-and-finish) records the
passing Review Report as the review gate.

Merge, auto-merge queueing, release, deploy, close, and source-branch cleanup
authority remain separate. Each requires an explicit `Finish authority` value and
verifiable `Finish authority source`, and approval never implies them. The one
project default below is that value for the parent's direct merge.

Parent-managed dev-flow finish ownership is explicit: `Finish owner: parent`. In the `issue-delivery-loop` skill's parent-orchestrated child-builder plus final-reviewer mode, the parent owns approval and the exact-head direct merge after a fresh guarded pass review, under the project default below. The reviewer owns only the Review Report verdict and evidence, then routes `Next action: finish-by-authorized-actor` back to the parent/authorized finisher.

#### Finish authority default

This section is the verifiable `Finish authority source` for the one project
default, `project default: the parent finisher may directly merge the reviewed
head`; quote that claim in the Reviewer Lift `Finish authority` row and the finisher
verifies it through the common guard. The default applies only when it is the value
quoted in that row: an explicit human/parent grant takes precedence over it, so an
explicit `queue auto-merge` grant is refused as `sha-bound-action-unsupported` even
though this default exists. It grants the `Finish owner: parent` finisher the
exact-head direct merge
([native integration](native-integration.md#ready-approval-and-finish)) after a
fresh guarded pass review, a valid exact-candidate Gate Receipt and the common
guard. Required check `check` may hold or refuse that merge: `main` protection
enforces admins, so GitHub holds it for every account, the sole admin included, until
`check` passes. That is GitHub's outcome, never an eligibility decision, and the
finisher never reads `check` to decide eligibility. On a hold the
[wait recipe](native-integration.md#wait-for-required-checks) waits within the
required-check wait budget before the guarded merge re-runs; a failed `check` or an
elapsed budget leaves the PR blocked with GitHub's outcome. The default grants
nothing else: not queueing (this repo's GitHub binding refuses it as
`sha-bound-action-unsupported`), and not a reviewer's own merge, release, deploy,
close or source-branch cleanup.

### Release/deploy policy

This skills repo has no product deploy path. Release actions for skill packages
or installed skill surfaces require explicit human or workflow authority and must
cite the authority source in the PR. This release/deploy policy does not grant
merge, auto-merge, release, deploy, or operator authority by itself.

### Auxiliary project-index policy

Parent/coordinator checkouts own generated auxiliary project-index updates by default. Child worktrees treat index reports as read-only unless the project profile explicitly assigns index updates to the child. Child worktrees must not copy index artifacts between worktrees; regenerate assigned indexes in the owning checkout instead.

## Usage rules

- Invoke the `forge` skill before shared workflow reads or actions; this target's confirmed integration is [native-integration.md](native-integration.md).
- Before converting an approved plan into tracker issues, invoke the `plan-to-issues` skill after the `forge` skill's `preflight`.
- Before implementation, invoke the `start-build` skill; before independent review, invoke the `start-review` skill.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
