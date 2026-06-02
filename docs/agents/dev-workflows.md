# Dev Workflows

This repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab-local`** — authoritative `glab` CLI reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, and known flag pitfalls.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using vertical slices and this repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, and delivery metrics in one place. See `issue-delivery-loop/SKILL.md`.
- **`/post-merge-verifier`** — read-only post-merge verification after merge or protected auto-merge: default-branch state, linked issue closure or pending closure, CI evidence, source-branch cleanup, and blockers. See `post-merge-verifier/SKILL.md`.

## Active recipes

- `issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps command syntax in `/gitlab-local`.
- `start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `/post-merge-verifier`; the stable compatibility anchor remains `start-build/BUILD-FLOW.md#parent-orchestrator-recipe`.
- `post-merge-verifier/SKILL.md` — active read-only verifier skill for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab-local` for command syntax instead of copying snippets here.
- `start-build/templates/gitlab-delivery-schema.md` — canonical shared GitLab `delivery.kind=gitlab-delivery` block and evidence/action taxonomy; compact delivery fields are routing indexes until verified from Tier 1/Tier 2 evidence.

## Project-profile hooks

GitLab workflow skills keep global schema names GitLab-specific: `issue`, `MR`,
`pipeline`, `source branch`, `target branch`, and `SHA`. This repo declares
project-specific policy through bounded `project_profile` extension fields in
[`start-build/templates/gitlab-delivery-schema.md`](../../start-build/templates/gitlab-delivery-schema.md);
do not invent provider-neutral aliases for the GitLab records.

| Project-profile field | Declaration location for this repo |
| --- | --- |
| `profile_id` / `profile_path` | `default` / this section. |
| `gate_policy_ref` | [`docs/agents/check-gate.md`](check-gate.md) full local gate and when-gate-cannot-run sections. |
| `label_profile_ref` | [`docs/agents/triage-labels.md`](triage-labels.md) live label inventory and agent rules. |
| `language_families` | Node.js/JavaScript, Bash/shell, Markdown, and YAML. |
| `branch_naming` | This doc's [Branch naming](#branch-naming) section. |
| `ci_jobs` | [`docs/agents/check-gate.md`](check-gate.md) CI parity / required jobs section. |
| `domain_docs` | [`docs/agents/domain.md`](domain.md) context and ADR layout. |
| `release_deploy_policy` | This doc's [Release/deploy policy](#releasedeploy-policy) section. |
| `manual_validation_rules` | [`docs/agents/check-gate.md`](check-gate.md) manual validation rules section. |
| `auxiliary_index_policy` | This doc's [Auxiliary project-index policy](#auxiliary-project-index-policy) section. |

Project-profile hooks may specialize this repo's policy, but they must not
weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
independent review, the child-builder boundary, the verifier read-only boundary,
or help-first `glab` correctness.

### Branch naming

Use issue-referencing source branches for GitLab MRs, for example
`issue-<iid>-<slug>`. Do not rename the delivery schema's `source_branch` or
`target_branch` fields.

### Review approval / merge policy

Reviewer approval is allowed by default after a passing review unless an
explicit human/parent instruction, MR or issue note, or project rulebook section
restricts it. Use this section, or
`start-review/REVIEW-FLOW.md#approval-authority-policy`, as the stable repo
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

- Before any GitLab CLI command, load `/gitlab-local`.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
