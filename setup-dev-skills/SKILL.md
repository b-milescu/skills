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
Shared [field guidance](skill://setup-dev-skills/reference/project-profile-facts.json) is not a profile:
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

Ask concrete **unresolved** choices one at a time, e.g. which named push repository
is intended, where work items live, which available tool reaches the named scope,
or which conflicting reference is authoritative. Do not present a platform menu,
repeat already-confirmed choices or require unrelated authentication.

Confirm target-owned integration recipes for forge's five operations, including
operation-specific required systems, unsupported outcomes, pagination, exact-head
guarantees, normalization and lossless readback/recovery. Configuration is not an
action-authority grant. Keep common safety floors with forge/delivery owners.

For labels, document live names and triage-role mapping as-is; no automatic live
creation/rename/delete. For domain, respect existing single/multi-context layout.
For gate, identify exact local command/runtime/bootstrap; absent full gate requires
explicit rationale and owner choice, not fabricated PASS. CI remains advisory.

## Present and confirm

Show the target profile/reference pointers, complete target-owned integration
doc, existing-root Agent Setup Docs (tracker, labels, domain, gate, guardrails,
workflows), and complete runtime-specific same-name project agent declarations.
Use [neutral tracker seed](skill://setup-dev-skills/issue-tracker.md) and
[workflow seed](skill://setup-dev-skills/dev-workflows-generic.md) as field guidance only. Include evidence,
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
canonical builder/reviewer entry pointers, role/authority bounds, runtime-specific
model/effort pins and confirmed exact/server-scoped tools. Determine each runtime's
native project location and precedence independently from runtime evidence. Keep
shared presets free of native server catalogues; do not widen to generic `mcp_*`.
Selected-file/skill provenance from the actual spawning session and independently
invoked allocated/revision checkouts must be verified separately from accessible
entries/tools. Metadata is not hard confinement; no external runtime patch.

Done when confirmed pointers resolve in the invoked target, recipes support its
real available operations, docs/declarations preserve custom facts and all limits
are explicit. Live installation and operator mutations remain outside setup.
