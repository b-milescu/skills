# Dev Workflows

Confirmed profile: `<target profile id>` at `<profile_path>`.
Selected `provider.reference`: `<target-owned integration doc or section>`.
Intended code/change, work-item and advisory CI scopes: `<independently verified scopes>`.
Named fetch/push remotes and fork intent: `<confirmed target choices>`.

Shared field guidance: the `setup-dev-skills` skill's
`reference/project-profile-facts.json` (no default target profile). Shared
delivery uses the `forge`, `start-build`, `start-review`, `plan-to-issues`,
`issue-delivery-loop` and `retro` skills through confirmed target pointers. Local
work items bind filesystem scope. Refresh only systems required by the requested
operation; missing or unsupported actions block only that operation. Configuration
grants no action authority.

Canonical resources, each named as its skill plus the path inside that skill:

- `forge` skill: `SKILL.md`, `reference/common-guard.md`
- `start-build` skill: `templates/delivery-schema.md`, `templates/reviewer-lift-schema.md`, `reference/parent-owned-gate.md`
- `start-review` skill: `REVIEW-FLOW.md`

This profile declares confirmed custom Agent Setup Doc paths, exact Check Gate
command/runtime/bootstrap, label/readiness vocabulary, branch policy, advisory CI,
domain/ADR paths, release/deploy policy, manual acceptance evidence and auxiliary
index ownership. Hooks preserve the safety floors (`start-build` skill,
`SAFETY.md#safety-floors`).

Complete runtime-specific same-name project declarations point at canonical skill
entries and preserve role bounds and task-selected specialists. Follow native model
and effort selection (`start-build` skill,
`reference/parent-orchestrator.md#native-model-and-effort-selection`). Native
tool selectors come only from confirmed available target tools; metadata is not
hard confinement. Establish each runtime's precedence and selected-file/skill
provenance separately from actual spawning and allocated/revision sessions.
Resolve canonical builder/final-reviewer roles through the effective spawning
inventory, preserving native qualified IDs and verified target-project precedence
under native route selection (`start-build` skill,
`reference/parent-orchestrator.md#native-route-selection`).
Keep logical skill IDs stable: record each skill and route by its logical name;
runtimes may namespace plugin entries, so each runtime-specific declaration uses
the identifier its own inventory exposes. Resource access does not supply target
policy or prove preload execution. Resolve helper paths relative to the owning
skill's directory, not the target CWD, before execution. Installed aliases keep
underlying source ownership and never replace this target's profile, identity,
paths, vocabulary or policy.
