# Dev Workflows

This target repo uses GitLab-backed dev workflows.

## Skills

- **`/gitlab`** — authoritative MCP-first GitLab transport reference for local/self-hosted GitLab: preflight, issues, MRs, CI, diffs, notes, approvals, merges, guarded `glab` fallback/helper conditions, and known MCP gaps.
- **`/gitlab-to-issues`** — break an approved plan, spec, PRD, or conversation into independently-grabbable GitLab issues using the target repo's triage labels.
- **`/start-build`** — pick up scoped GitLab issues, implement with TDD where applicable, and open Draft MRs with Review Packets.
- **`/start-review`** — review GitLab MRs against project rules, safety invariants, CI, and test evidence; approve, request changes, reject, or merge when authority allows.
- **`/issue-delivery-loop`** — coordinate bounded ready-issue batches and issue-to-MR loops; keep Decoupling Contract proof, parent spot-checks, revision routing, delivery metrics, and post-merge verifier recipe handoff in one place. See `skill://issue-delivery-loop/SKILL.md`.

## Active recipes

- `skill://issue-delivery-loop/SKILL.md` — coordinator wrapper for ready-issue batches and issue-to-MR loops; delegates implementation/review to `start-build` / `start-review`, enforces Decoupling Contract before parallel fan-out, and keeps GitLab transport details in `/gitlab`.
- `skill://start-build/reference/parent-orchestrator.md` — active project-agnostic parent loop for GitLab issue-to-MR work: issue resolution, durable child outputs, child `mr-builder` handoff, parent spot-check, `mr-reviewer`, revision rounds, SHA/CI guards, authority-aware finish, cleanup, and post-merge verification via `skill://start-build/reference/post-merge-verifier.md`; the stable compatibility anchor remains `skill://start-build/BUILD-FLOW.md#parent-orchestrator-recipe`.
- `skill://start-build/reference/post-merge-verifier.md` — canonical read-only verifier recipe for merged/default-branch state, linked issue closure or pending closure, branch cleanup, and documented non-mutating post-merge validation. Use `/gitlab` and `skill://get_post_merge_snapshot` for transport/helper behavior instead of copying snippets into generated setup docs.
- `skill://start-build/templates/gitlab-delivery-schema.md` — canonical shared GitLab `delivery.kind=gitlab-delivery` block, `project_profile` hook field list, evidence/action taxonomy, and generated-copy drift contract.
- `skill://setup-dev-skills/reference/project-profile-facts.json` — canonical Setup Skill fact source for target Agent Setup Doc paths, tracker fields, Triage Role-to-live-label mappings, Check Gate refs, Dev Workflow refs, branch naming, CI parity, and runtime skill-resource URIs.

When adapting this seed into the target repo's Dev Workflow doc, instantiate the target-specific paths, labels, gate command, branch naming, CI jobs, and skill-resource refs from `skill://setup-dev-skills/reference/project-profile-facts.json` plus live repo inspection. Keep active recipe pointers conceptually aligned with the target repo's workflow docs while leaving project-specific design briefs, labels, gate commands, branch naming, CI jobs, release/deploy policy, manual validation rules, and merge authority in the target repo's own setup docs.

## Skill-only tier routing

Tier routing enforced only flows launched through `/issue-delivery-loop` parent loop. Manual direct agent selection outside enforcement surface. skill docs choose exact route basenames. Model pins live in frontmatter; provider effort pins live too.

Before child launch, `/issue-delivery-loop` classifies each target issue/MR as `trivial`, `moderate`, or `high-risk` (tier criteria live in `skill://issue-delivery-loop/SKILL.md`). The single canonical tier→builder route table is owned by `skill://start-build/reference/parent-orchestrator.md`, names shared model-free route basenames, and resolves each basename in the current dialect directory (`agents/claude/<route>.md` or `agents/omp/<route>.md`); this seed does not restate the per-tier builder route rows. Route basenames are distinct from role/mode labels such as `child mr-builder` and `mr-reviewer`.

Independent-review floors hold every tier: mandatory final-reviewer route is `mr-reviewer-final`, resolved from current dialect directory. Missing route remains route-unavailable blocker; no review scout, generic fallback, shim, old filename, or cross-runtime substitute is allowed.

## Project-profile hooks

GitLab workflow skills keep global schema names GitLab-specific: `issue`, `MR`,
`pipeline`, `source branch`, `target branch`, and `SHA`. Target repos declare
project-specific policy through the bounded `project_profile` extension fields
documented in `skill://start-build/templates/gitlab-delivery-schema.md`; do not invent
provider-neutral aliases for the GitLab records.

Use the Setup Skill fact source (`skill://setup-dev-skills/reference/project-profile-facts.json`) to distinguish default seed paths from target-selected paths. The table below names the default doc locations; generated target docs substitute the target profile's paths when they differ.

Declare project policy in these setup docs:

| Project-profile field | Declaration location |
| --- | --- |
| `profile_id` / `profile_path` | This doc's project-profile section. |
| `gate_policy_ref` | `docs/agents/check-gate.md` full local gate and when-gate-cannot-run sections. |
| `label_profile_ref` | `docs/agents/triage-labels.md` live label inventory and agent rules. |
| `acceptance_surfaces_ref` | This doc's acceptance-surface vocabulary section, using the target repo's own surface values. When the target repo declares no vocabulary, `acceptance_surfaces` is fail-closed to `[]`/`none`. |
| `language_families` | This doc, using the target repo's language/tooling families. |
| `branch_naming` | This doc's branch naming section. |
| `ci_jobs` | `docs/agents/check-gate.md` CI parity / required jobs section. |
| `domain_docs` | `docs/agents/domain.md` context and ADR layout. |
| `release_deploy_policy` | This doc's release/deploy policy section. |
| `manual_validation_rules` | `docs/agents/check-gate.md` manual validation rules section. |
| `auxiliary_index_policy` | This doc's auxiliary project-index policy section. |

Triage Role names map to live labels through the target repo's label vocabulary. Do not hardcode this repo's label strings into generated docs unless the target profile's live label inventory records those exact strings.

Project-profile hooks may specialize target-repo policy, but they must not
weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
independent review, the child-builder boundary, the verifier read-only boundary,
or MCP-first transport correctness plus help-first `glab` fallback correctness.

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

- Before any GitLab API action, load `/gitlab` and follow MCP-first transport order; use `glab` only for documented guarded fallback/helper/troubleshooting cases.
- Use `skill://setup-dev-skills/reference/project-profile-facts.json` as the generation/verification source for target-specific docs, label vocabulary, Check Gate refs, Dev Workflow refs, and skill-resource addressing.
- Before converting an approved plan into GitLab issues, load `/gitlab-to-issues`.
- Before implementation from GitLab issues, load `/start-build`.
- Before MR review, load `/start-review`.
- Project docs in `CLAUDE.md` / `AGENTS.md`, `docs/agents/`, `CONTEXT.md`, and ADRs override generic skill defaults where stricter.
- Issue readiness criteria are owned by `skill://gitlab-to-issues/docs/agents/agent-readiness-scorecard.md` and the target repo's triage-labels doc; setup must keep the skill-owned scorecard portable and target repo label policy repo-relative.
