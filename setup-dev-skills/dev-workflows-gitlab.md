# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, delivery metrics, and post-merge verifier recipe handoff in one place. See `issue-delivery-loop/SKILL.md`.

## Active recipes

- `issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps command syntax in `/gitlab-local`.
- `start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for GitLab issue-to-MR work: issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `start-build/reference/post-merge-verifier.md`; the stable compatibility anchor remains `start-build/BUILD-FLOW.md#parent-orchestrator-recipe`.
- `start-build/reference/post-merge-verifier.md` — canonical read-only verifier recipe for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab-local` and `gitlab-local/scripts/gitlab-post-merge-snapshot.sh` for command behavior instead of copying snippets into generated setup docs.
- `start-build/templates/gitlab-delivery-schema.md` — canonical shared GitLab `delivery.kind=gitlab-delivery` block, `project_profile` hook field list, evidence/action taxonomy, and generated-copy drift contract.

When adapting this seed into `docs/agents/dev-workflows.md`, keep these active recipe pointers conceptually aligned with the target repo's workflow docs while leaving project-specific design briefs, labels, gate commands, branch naming, CI jobs, release/deploy policy, manual validation rules, and merge authority in the target repo's own setup docs.

## Project-profile hooks

GitLab workflow skills keep global schema names GitLab-specific: `issue`, `MR`,
`pipeline`, `source branch`, `target branch`, and `SHA`. Target repos declare
project-specific policy through the bounded `project_profile` extension fields
documented in `start-build/templates/gitlab-delivery-schema.md`; do not invent
provider-neutral aliases for the GitLab records.

Declare project policy in these setup docs:

| Project-profile field | Declaration location |
| --- | --- |
| `profile_id` / `profile_path` | This doc's project-profile section. |
| `gate_policy_ref` | `docs/agents/check-gate.md` full local gate and when-gate-cannot-run sections. |
| `label_profile_ref` | `docs/agents/triage-labels.md` live label inventory and agent rules. |
| `language_families` | This doc, using the target repo's language/tooling families. |
| `branch_naming` | This doc's branch naming section. |
| `ci_jobs` | `docs/agents/check-gate.md` CI parity / required jobs section. |
| `domain_docs` | `docs/agents/domain.md` context and ADR layout. |
| `release_deploy_policy` | This doc's release/deploy policy section. |
| `manual_validation_rules` | `docs/agents/check-gate.md` manual validation rules section. |
| `auxiliary_index_policy` | This doc's auxiliary project-index policy section. |

Project-profile hooks may specialize target-repo policy, but they must not
weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
independent review, the child-builder boundary, the verifier read-only boundary,
or help-first `glab` correctness.

### Branch naming

Record the source branch convention for GitLab MRs here. A common pattern is
`issue-<iid>-<slug>`. This is a project policy hook only; the delivery schema
field names remain `source_branch` and `target_branch`.

### Review approval / merge policy

Reviewer approval is allowed by default after a passing review unless an
explicit human/parent instruction, MR or issue note, or project rulebook section
restricts it. When adapting this seed, keep a stable target-repo policy source
for `Approval authority: default-after-pass`.

Merge, auto-merge, release, deploy, close, and source-branch cleanup authority
remain separate. They require an explicit `Merge authority` value and
verifiable `Merge authority source`; approval never implies those finish
actions.

### Release/deploy policy

Record who can authorize release/deploy actions and which docs or manual
validation rules must be cited. Setup docs must not grant merge, auto-merge,
release, deploy, or operator authority by themselves.

### Auxiliary project-index policy

Parent/coordinator checkouts own generated auxiliary project-index updates by default. Child worktrees treat index reports as read-only unless the project profile explicitly assigns index updates to the child. Child worktrees must not copy index artifacts between worktrees; regenerate assigned indexes in the owning checkout instead.

## Usage rules

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md` / `AGENTS.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
- Issue readiness criteria are owned by `/gitlab-to-issues` and the target repo's triage-labels doc; setup does not generate a separate readiness doc.
