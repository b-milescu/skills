---
name: setup-dev-skills
description: Establishes or reconciles the invoked project's confirmed integration, policy pointers and runtime declarations from evidence and owner choices.
disable-model-invocation: true
---

# Setup Dev Skills

User-invoked and human-confirmed: inspect, resolve only missing choices, present
complete draft, confirm, write. Other skills may recommend this entry for absent
or stale setup, but never auto-run it, login, install or mutate live labels.

## Explore the invoked target

Read explicit owner intent and the target rulebook's existing `project_profile`,
`profile_path`, `provider.reference`, policy/docs pointers and custom roots.
Shared [field guidance](reference/project-profile-facts.json) is not a profile:
it contains no target identity, vocabulary, host, default paths or detector.

Inspect named fetch **and** push remotes, fork intent, code/change-request,
work-item and CI configuration separately. Read referenced docs and available-tool
documentation; use operation-scoped read-only native verification to compare
intended system/repository scopes and authenticated identities. Local work items
bind confirmed filesystem scope. Do not infer tracker from host branding, a word
in a path, first remote or installed tools. Unavailable tools are evidence limits,
not permission to erase known configuration or declare unrelated actions blocked.

Inspect current domain/ADR layout, gate commands/runtime/bootstrap, coding
conventions, live label vocabulary and runtime-specific agent declaration locations.
Preserve issue/task-selected specialist policy; no unconditional specialist preload.

## Resolve choices

Summarize verified, conflicting and unavailable evidence first. With existing
setup, propose reconciliation in place while preserving custom paths, vocabulary
and user additions; no legacy reader or bulk profile conversion.

Ask concrete **unresolved owner choices** one at a time, e.g. which named push
repository is intended, where work items live, which available tool reaches the
named scope, or which conflicting reference is authoritative. Do not present a
platform menu, repeat confirmed choices, require unrelated authentication or ask
the owner to discover undocumented provider ceilings/counting units.

Confirm target-owned integration recipes for forge's five operations, including
operation-specific required systems, unsupported outcomes, pagination, the
[packet home](../forge/SKILL.md#packet-home), applicable authoritative limits/units
and their evidence or explicit undocumented capacity, exact-head guarantees,
required-check holds with the signal that ends their wait and any bound
other than the default [required-check wait budget](../start-build/reference/parent-orchestrator.md#required-check-wait-budget),
normalization and lossless readback/recovery. A confirmed native-validation recipe
may permit one otherwise authorized ordinary publication with an undocumented
ceiling/unit: retain the pre-write original, validate safe text, bind the actual
native artifact and require full string-valued body/original-byte equality per
forge. Record possible refusal/unverified artifacts and manual recovery, not
unlimited capacity or an invented default. A note home still records its pointer
form, same-change/current-head resolution and independent append/readback then
pointer-update/readback recipe.

Exact-head direct merge requires a documented stale-head rejection guarantee or
the owner-confirmed probe below; a request field/schema alone proves no guarantee.
Queue head binding must survive through actual merge, not merely acceptance.
Unsupported or unproven bindings are refused as `sha-bound-action-unsupported`,
with no unbound fallback or direct merge under queue authority.

Where rejection is undocumented, describe this probe for an explicitly authorized
actor; setup does not execute it or implicitly grant probe/cleanup authority:
create disposable source and target branches and a disposable change request;
capture the old full head, advance source to a new full head, then request native
merge bound to the **old** head. Require refusal and an unmerged native post-read.
Record date, change/request locator and identity, both full SHAs, refusal
status/response and unmerged post-read in the target reference. Accepted or
unproven outcomes leave exact-head direct merge unsupported. Obtain explicit
probe and cleanup authority; after recording, the authorized actor closes/deletes
disposable artifacts. Never use protected/shared branches. A documented stale-head
rejection guarantee needs no live probe.
Configuration is not an action-authority grant. Keep common safety floors with
forge/delivery owners.

For labels, document live names and triage-role mapping as-is; no automatic live
creation/rename/delete. For domain, respect existing single/multi-context layout.
For gate, identify exact local command/runtime/bootstrap; absent full gate requires
explicit rationale and owner choice, not fabricated PASS. CI remains advisory.

## Present and confirm

Show the target profile/reference pointers, complete target-owned integration
doc, existing-root Agent Setup Docs (tracker, labels, domain, gate, guardrails,
workflows), and complete runtime-specific same-name project agent declarations.
Use [neutral tracker seed](issue-tracker.md) and
[workflow seed](dev-workflows-generic.md) as field guidance only. Include evidence,
operation limits, unresolved choices and source ownership of installed aliases.
Write only after human confirmation.

## Write confirmed changes

Update the existing rulebook's Agent skills block and pointers in place without
touching unrelated content; if no rulebook exists ask which native one to create.
Multiple blocks/conflicting sources require owner resolution. Substitute paths
from target `project_profile.agent_setup_docs`, never from installation defaults.
Preserve valid custom sections and additions. Authored docs stay Markdown.

Reuse `project_profile`, `profile_path` and selected `provider.reference` resolving
the target integration doc/section; no second config, catalogue, dispatcher,
generator or adapter registry. `provider` names and records are opaque scoped
values. A second target with other mechanics needs only its own confirmed docs.

Runtime declarations are **complete shallow files**, not metadata overlays:
canonical builder/reviewer entry pointers, role/authority bounds and
runtime-specific model/effort neutrality per [native selection](../start-build/reference/parent-orchestrator.md#native-model-and-effort-selection).
They declare no tool allowlist, so each inherits every tool of the spawning
session; the target's confirmed integration, not the declaration, names the tools
its recipes need. Determine each runtime's native project location and precedence
independently from runtime evidence. Selected-file/skill provenance from the actual
spawning session and independently invoked allocated/revision checkouts must be
verified separately from accessible entries/tools; no external runtime patch.
Resolve canonical roles through the effective runtime inventory under
[native route selection](../start-build/reference/parent-orchestrator.md#native-route-selection);
record exposed identifiers separately from canonical basenames and source files.
Preserve deterministic native preload identifiers without changing logical skill
IDs; discovery metadata does not prove preload execution or effort enforcement.

Configuration-complete means confirmed pointers resolve in the invoked target,
docs/declarations preserve custom facts, and each operation's supported/refused
recipes, known bounds and evidence gaps are explicit. Report this separately from
selected-operation delivery readiness: a refused or unverified publication required
by that delivery blocks delivery-ready, even when configuration is complete.
Setup does not claim future publication, gate or review success. Live installation
and operator mutations remain outside setup; configuration grants no authority.
