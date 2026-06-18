# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab`** — authoritative MCP-first GitLab transport reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, guarded `glab` fallback/helper conditions, and known MCP gaps.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, delivery metrics, and post-merge verifier recipe handoff in one place. See `skill://issue-delivery-loop/SKILL.md`.
- **`/retro`** — delivery retrospective: mine a finished build/review/delivery session for friction evidence and propose bounded improvements as routed follow-up issues. Proposal-only; never edits skills or docs directly. See `skill://retro/SKILL.md`.

## Active recipes

- `skill://issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps GitLab transport details in `/gitlab`.
- `skill://start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `skill://start-build/reference/post-merge-verifier.md`; the stable compatibility anchor remains `skill://start-build/BUILD-FLOW.md#parent-orchestrator-recipe`.
- `skill://start-build/reference/post-merge-verifier.md` — canonical read-only verifier recipe for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab` and `skill://get_post_merge_snapshot` for transport/helper behavior instead of copying snippets here.
- `skill://start-build/templates/gitlab-delivery-schema.md` — canonical shared GitLab `delivery.kind=gitlab-delivery` block and evidence/action taxonomy; compact delivery fields are routing indexes until verified from Tier 1/Tier 2 evidence.
- `skill://setup-dev-skills/reference/project-profile-facts.json` — canonical Setup Skill fact source used to verify this repo's Agent Setup Doc paths, live label mappings, Check Gate refs, Dev Workflow refs, branch naming, CI parity, and runtime skill-resource URIs.
- `skill://start-build/reference/parent-owned-gate.md` — canonical parent-owned Check Gate / Gate Receipt seam for child handoff ownership fields, receipt schema, parent verification checklist, ready-transition conditions, exact-SHA Gate coverage handling, and evidence-ready tokens. Cross-project invocations use `skill://start-build/reference/parent-owned-gate.md`; target repo Check Gate policy stays repo-relative at `docs/agents/check-gate.md`.
- `skill://gitlab/reference/mutation-guard.md` — canonical GitLab Mutation Guard seam for mutating GitLab actions. Cross-project invocations use `skill://gitlab/reference/mutation-guard.md`, `skill://gitlab/reference/mutation-guard.schema.json`, and `skill://gitlab/reference/snippet-transports.md` for guard resources while keeping target-repo policy references repo-relative (`docs/agents/...`).
- `skill://gitlab/reference/authority-verification.md` — canonical Authority Verification seam for approval/merge authority claim shape, source precedence, conflict/restriction/missing-source results, verified authority output, action routing, and no-self approval/merge context. Cross-project invocations use `skill://gitlab/reference/authority-verification.md` and `skill://gitlab/reference/authority-verification.schema.json`.

## Skill-only tier routing

Tier routing enforced only flows launched through `/issue-delivery-loop` parent loop. Manual direct agent selection outside enforcement surface. skill docs choose exact route basenames. Model pins live in frontmatter; provider effort pins live too.

Before child launch, `/issue-delivery-loop` classifies target issue/MR `trivial`, `moderate`, or `high-risk` (tier criteria live in [`skill://issue-delivery-loop/SKILL.md`](skill://issue-delivery-loop/SKILL.md)). The single canonical tier→builder route table is owned by [`skill://start-build/reference/parent-orchestrator.md`](skill://start-build/reference/parent-orchestrator.md), names shared model-free route basenames, and resolves each basename in the current dialect directory (`agents/claude/<route>.md` or `agents/omp/<route>.md`); this doc does not restate per-tier builder route rows. Route basenames are distinct from role/mode labels such as `child mr-builder` and `mr-reviewer`.

Independent-review floors hold every tier: mandatory final-reviewer route is `mr-reviewer-final`, resolved from current dialect directory. Missing route remains route-unavailable blocker; no review scout, generic fallback, shim, old filename, cross-runtime substitute is allowed.

## Project-profile hooks

GitLab workflow skills keep global schema names GitLab-specific: `issue`, `MR`,
`pipeline`, `source branch`, `target branch`, and `SHA`. This repo declares
project-specific policy through bounded `project_profile` extension fields in
[`skill://start-build/templates/gitlab-delivery-schema.md`](skill://start-build/templates/gitlab-delivery-schema.md);
do not invent provider-neutral aliases for the GitLab records.

This repo uses the default profile from `skill://setup-dev-skills/reference/project-profile-facts.json`: repo-local policy docs stay under `docs/agents/...`, while reusable cross-project resources use explicit `skill://...` URIs.

| Project-profile field | Declaration location for this repo |
| --- | --- |
| `profile_id` / `profile_path` | `default` / this section. |
| `gate_policy_ref` | [`docs/agents/check-gate.md`](check-gate.md) full local gate, Gate coverage for ready handoff, CI parity, and when-gate-cannot-run sections. |
| `label_profile_ref` | [`docs/agents/triage-labels.md`](triage-labels.md) live label inventory and agent rules. |
| `acceptance_surfaces_ref` | This doc's [Acceptance-surface vocabulary](#acceptance-surface-vocabulary) section. |
| `language_families` | Node.js/JavaScript, Bash/shell, Markdown, and YAML. |
| `branch_naming` | This doc's [Branch naming](#branch-naming) section. |
| `ci_jobs` | [`docs/agents/check-gate.md`](check-gate.md) CI parity / required jobs section. |
| `domain_docs` | [`docs/agents/domain.md`](domain.md) context and ADR layout. |
| `release_deploy_policy` | This doc's [Release/deploy policy](#releasedeploy-policy) section. |
| `manual_validation_rules` | [`docs/agents/check-gate.md`](check-gate.md) manual validation rules section. |
| `auxiliary_index_policy` | This doc's [Auxiliary project-index policy](#auxiliary-project-index-policy) section. |

Triage Role names map through this repo's live label vocabulary in `docs/agents/triage-labels.md`; reusable skills must read that mapping instead of assuming a global label string.

Project-profile hooks may specialize this repo's policy, but they must not
weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
independent review, the child-builder boundary, the verifier read-only boundary,
or MCP-first transport correctness plus help-first `glab` fallback correctness.

### Acceptance-surface vocabulary

This repo's `project_profile.acceptance_surfaces_ref` resolves here. These are
the only allowed `acceptance_surfaces` surface values for this repo; the global
evidence enum (`test`, `smoke`, `docs-read`, `ci`, `N/A — <reason>`) stays in
[`skill://start-build/templates/gitlab-delivery-schema.md`](skill://start-build/templates/gitlab-delivery-schema.md).

| Surface value | Meaning |
| --- | --- |
| `docs` | Documentation files changed or read as evidence. |
| `prompt` | Agent prompt / SKILL.md / agent definition file changed. |
| `agent_inventory` | Agent inventory manifest or registry changed. |
| `install_surface` | Install script, symlink, or deploy artifact changed. |
| `transport` | GitLab transport / MCP / glab fallback logic changed. |
| `authority` | Authority verification, approval, or merge authority logic changed. |
| `ci_finish` | CI watch, finish guard, or CI-verdict logic changed. |
| `mutation_guard` | GitLab mutation guard or safe-text handling changed. |
| `tooling` | Repo-local helper script, validator, test harness, or dev-workflow tooling changed. |

When no surface above is touched, declare `acceptance_surfaces` as `[]`/`none`. A
declared surface without evidence, or an observably-changed surface that is not
declared, blocks ready/pass.

### Branch naming

Use issue-referencing source branches for GitLab MRs, for example
`issue-<iid>-<slug>`. Do not rename the delivery schema's `source_branch` or
`target_branch` fields.

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

### Release/deploy policy

This skills repo has no product deploy path. Release actions for skill packages
or installed skill surfaces require explicit human or workflow authority and must
cite the authority source in the MR. This release/deploy policy does not grant
merge, auto-merge, release, deploy, or operator authority by itself.

### Auxiliary project-index policy

Parent/coordinator checkouts own generated auxiliary project-index updates by default. Child worktrees treat index reports as read-only unless the project profile explicitly assigns index updates to the child. Child worktrees must not copy index artifacts between worktrees; regenerate assigned indexes in the owning checkout instead.

## Design briefs

- `docs/agents/mr-build-review-orchestration.md` — issue #55 historical design brief for the parent-orchestrator loop. It records rationale, provenance, and links to active sources; active workflow policy now lives in the recipe above.

## Usage rules

- Before any GitLab API action, load `/gitlab` and follow MCP-first transport order; use `glab` only for documented guarded fallback/helper/troubleshooting cases.
- For GitLab mutations, follow the GitLab Mutation Guard from `skill://gitlab/reference/mutation-guard.md`; keep this repo's `docs/agents/...` policy references repo-relative when working from another project.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
