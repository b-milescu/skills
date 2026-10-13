---
name: forge
description: >-
  Operates the invoked project's confirmed integration. Use to bind scopes,
  read work-item/change-request/CI evidence, publish a durable artifact,
  take a guarded action, or verify merged state.
---

# Forge

## Resource resolution

Use native runtime metadata to establish this file's absolute filesystem
path; if only the skill directory is given, append `SKILL.md`.
Resolve relative skill-bundle links against the directory of the file
containing the link, normalize `..`, strip Markdown fragments, and read the
resulting absolute filesystem path. Rebase again from each subsequently
loaded file. Never append parent-relative links to a resource URI or use the
target repository's working directory as the skill-resource base.

Target project/profile/provider references stay bound to the verified
target checkout, not the skill installation.

A model-invoked instruction seam with five operations. Bind **the invoked target's**
confirmed `project_profile`, `profile_path` and selected `provider.reference`.
Resolve that reference in the target checkout, not the skill installation or an
installed alias; resolve mechanics under [operation-time recipes](#operation-time-recipes).
No shared provider catalogue, host detector, default target profile or
tool-presence inference is used.

## Preflight

1. Read the target rulebook's profile pointer and selected integration reference.
   Missing/stale binding prompts the owner to run the `setup-dev-skills` skill;
   never auto-run setup, authentication, installation or live label changes.
2. Reconcile explicit owner intent, named fetch/push remotes and fork intent,
   configured code/change, work-item and CI scopes, and referenced policy. A
   tracker may be independent of code hosting; local work items bind verified
   filesystem scope and need no invented remote identity.
3. Resolve the active operation's [native mechanics](#operation-time-recipes).
   Verify canonical repository/default branch and required scopes against
   independent intended-target evidence. Compare IDs and locators within
   verified system/repository scope, never by local ID alone.
4. Capture immutable authenticated identity for each system this operation
   requires. Refresh/authenticate only required systems: unrelated CI or tracker
   authentication never blocks a supported operation. Record unavailable tools
   without erasing known configuration.

Ambiguous/conflicting binding blocks the affected operation. Unsupported actions
return an explicit scoped blocker; no guessed transport, silent integration
fallback or blanket refusal of unrelated supported operations. Configuration
never grants authority.

## Operation-time recipes

Use existing valid target recipes and stricter policy first. Consumer references
to target-owned native mechanics mean those recipes or missing mechanics resolved
here, never new policy. Resolve only the active operation's missing mechanics from
current documentation for the selected target's bound MCP/tool/API: required
scopes/identities, complete reads, write/fallback eligibility, validation,
post-read/recovery and relevant head/capacity guarantees. Record the selected
recipe and its documentation/evidence with the operation. A schema field or tool's
presence alone is not capability proof.

Use MCP first under target policy; resolve a documented native fallback only for
this call's unavailable MCP or a gap it actually supplies. Verify exact CLI help
only when that command is needed. Both transports bind the same verified scope
and immutable actor, never environment/CWD/global-config scope. For writes,
transport selection remains the ordered guard's fallback-eligibility phase.

Resolution never silently changes target, provider, policy or packet home,
grants authority, or installs/authenticates/configures tools. Conflicts need owner
resolution; missing required proof blocks only the affected operation before a
write. No all-five recipe matrix, unrelated identity sweep or advance capacity/
merge certification is required. Setup completion is not delivery readiness.

The ordered [common guard](reference/common-guard.md), including
[native validation](reference/common-guard.md#native-validation) and
[exact-head guarantees](reference/common-guard.md#exact-head-guarantees), remains
mandatory: documentation does not replace fresh scope/caller/head/authority
checks, original-source equality, one mutation/no mid-attempt switch or recovery.

## Operations

- **`preflight`** — the binding above, operation-scoped readiness policy and
  identity; optional bounded candidate discovery.
- **`snapshot`** — evidence-only [snapshot contract](reference/common-guard.md#snapshot-evidence).
  Follow target native pagination and lossless body recovery; lists are discovery,
  not decision-grade single-record evidence. Complete requested diff/discussions/
  reviews; unresolved truncation blocks the decision requiring completeness.
- **`publish`** — validate one authored durable artifact through
  [common guard](reference/common-guard.md), publish once using the selected
  recipe, and require native byte-preserving authored-source readback with only
  explicitly documented target normalization. Echoes and stored-body digests are
  not submitted-source equality. Known-created artifacts recover GET-only;
  unknown creation uses bounded reconciliation, never automatic repeat creation.
- **`act`** — run the ordered common guard, exactly one native mutation, then
  native post-read. Native protections/refusals are reported without bypass.
- **`post_merge_snapshot`** — read-only merged/linked-item state, result commit,
  containment, advisory result-bound CI and branch/worktree cleanup evidence.
  Queued is not merged; closure intent/preview are not observed item closure.

## Packet home

The Review Packet, with its Reviewer Lift, is the canonical durable handoff. It
lives at the **packet home** the selected reference designates. Record applicable
authoritative size limits, their units/evidence and any undocumented ceiling or
unit for packet and description. Enforce known bounds in their declared units;
unknown is not unlimited and never a guessed cap. A target-native
validation/readback recipe established and validated for the active publication
may permit one otherwise authorized ordinary attempt with an undocumented
ceiling/unit under [native validation](reference/common-guard.md#native-validation).
Without dependable pre-write proof, that publication blocks. Never probe a
ceiling, truncate, split or silently switch home/transport. The default home
remains the change-request description.

A note-home reference specifies the description pointer form and native refresh
recipe. First Draft creation may precede note publication, but the change remains
Draft/unready until the selected packet and pointer have verified readbacks.
Publish or refresh in this order: append a new complete packet note; require
byte-exact native readback; update the description pointer while preserving
provider-native closure syntax; require exact description readback. Each mutation
runs `forge publish` independently; there is no assumed transactional double-write.
Published notes are immutable, not edited to refresh a packet.

Discovery, gate/Lift rebind, handoff and review resolve **only the current
description pointer**, natively scoped to this same change request. Never select
by latest note or marker search: historical packets and reports may contain
copied Lift markers. Missing, stale, wrong-change or head-mismatched pointers block
affected transitions. The one-Lift-block rule applies within the current selected
packet, not across historical packet/report notes. Publication, safe-text,
applicable known-limit checks and original-source byte equality apply unchanged
at the selected home; a packet over a known applicable limit is refused
(`blocked`), never truncated. Unverified publication blocks dependent transitions.

## Helpers

Run helper scripts by their resolved absolute path, from the installed skill
the runtime loaded and never a copy in the checkout under review (a change
must not be validated by its own modified validator). Stack files that run
a helper cite this rule instead of restating it. For
`scripts/validate-text.mjs`, `<resolved-forge-dir>` is the absolute path of this
file's directory. Its JSON envelope validates exact string/finite role with
no-body diagnostics before body-bearing writes. Target safe-write tools may add
native checks, not replace common checks.

```text
bun <resolved-forge-dir>/scripts/validate-text.mjs --input <absolute-envelope.json>
```

Exact envelope: `{"role":"review-packet","content":"authored string"}` with only
those keys. Roles: `title`, `description`, `note`, `review-packet`, `receipt`,
`report`, `body`. Reject invalid/lossy UTF-8 decoding, malformed UTF-16, NUL,
non-whitespace C0 and DEL; allow tab/LF/CR and valid Unicode. Failures emit only
role/offset/type, never body or parser excerpts. Valid envelope content errors use
the supplied role and a UTF-16 content offset; envelope errors use `body`.

The [shared wrapper extraction contract](../start-build/reference/parent-owned-gate.md#shared-wrapper-extraction)
owns installed receipt materialization from complete authored and lossless
readback files; it proves neither receipt validity nor native attribution.
The selected target reference owns native identifiers/locators, tools, pagination,
normalization, closure syntax, the [packet home](#packet-home), capacity evidence,
native body recovery/validation/readback, draft/ready, native receipt field
extraction and actor/head/scope/custody attribution, approval/finish,
expected-head guarantees, required-check holds with the signal that ends their
wait and any bound other than the default
[required-check wait budget](../start-build/reference/parent-orchestrator.md#required-check-wait-budget),
and supported recovery. Shared records remain opaque;
explicit verified bindings, not string shape, establish trust. Ready pre/post
reads are observational unless the actual native operation guarantees atomicity;
finish/queue follow the [exact-head guarantees](reference/common-guard.md#exact-head-guarantees).
Before finish re-read the recorded allocated open item and exact
change/source/item relationship. Verifier cleanup retains dirty, foreign,
unknown, unmerged and containment-unverified state.
