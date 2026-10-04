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

The selected `provider.reference` states the packet home and its size limit (the
change-request description by default, or a durable note the description points to);
the stale-head rejection behind exact-head direct merge, which setup proves with a
live stale-head probe where the provider documents none; and that queueing that
cannot be bound to a head is refused as `sha-bound-action-unsupported`.

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
entries and preserve role bounds and task-selected specialists. They declare no
tool allowlist and inherit every tool of the spawning session. Follow native model
and effort selection (`start-build` skill,
`reference/parent-orchestrator.md#native-model-and-effort-selection`). Establish
each runtime's precedence and selected-file/skill provenance separately from actual
spawning and allocated/revision sessions.
Resolve canonical builder/final-reviewer roles through the effective spawning
inventory, preserving native qualified IDs and verified target-project precedence
under native route selection (`start-build` skill,
`reference/parent-orchestrator.md#native-route-selection`).
Keep logical skill IDs stable: record each skill and route by its logical name;
runtimes may namespace plugin entries, so each runtime-specific declaration uses
the identifier its own inventory exposes. Resource access does not supply target
policy or prove preload execution. Relative paths resolve against the directory of
the file that contains them; run helper scripts as the `forge` skill's `SKILL.md`
Helpers section directs. Installed aliases keep underlying source ownership and
never replace this target's profile, identity, paths, vocabulary or policy.
