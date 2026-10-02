---
name: forge
description: >-
  Operates the invoked project's confirmed integration. Use to bind scopes,
  read work-item/change-request/CI evidence, publish a durable artifact,
  take a guarded action, or verify merged state.
---

# Forge

A model-invoked instruction seam with five operations. Obtain mechanics from
**the invoked target's** confirmed `project_profile`, `profile_path` and selected
`provider.reference`. Resolve that reference in the target checkout, not the
skill installation or an installed `docs/` alias. No shared provider catalogue,
host detector, default target profile or tool-presence inference is used.

## Preflight

1. Read the target rulebook's profile pointer and selected integration reference.
   Missing/stale setup prompts the owner to invoke `/setup-dev-skills`; never
   auto-run setup, authentication, installation or live label changes.
2. Reconcile explicit owner intent, named fetch/push remotes and fork intent,
   configured code/change, work-item and CI scopes, and referenced policy. A
   tracker may be independent of code hosting; local work items bind verified
   filesystem scope and need no invented remote identity.
3. Follow the confirmed reference's available-tool documentation and read-only
   native recipes. Verify canonical repository/default branch and operation's
   required scopes against independent intended-target evidence. Compare IDs
   and locators within verified system/repository scope, never by local ID alone.
4. Capture immutable authenticated identity for each system this operation
   requires. Refresh/authenticate only required systems: unrelated CI or tracker
   authentication never blocks a supported operation. Record unavailable tools
   without erasing known configuration.

Ambiguous/conflicting binding blocks the affected operation. Unsupported actions
return an explicit scoped blocker; no guessed transport, silent integration
fallback or blanket refusal of unrelated supported operations. Configuration
never grants authority.

## Operations

- **`preflight`** — the binding above, operation-scoped readiness policy and
  identity; optional bounded candidate discovery.
- **`snapshot`** — evidence-only [snapshot contract](skill://forge/reference/common-guard.md#snapshot-evidence).
  Follow target native pagination and lossless body recovery; lists are discovery,
  not decision-grade single-record evidence. Complete requested diff/discussions/
  reviews; unresolved truncation blocks the decision requiring completeness.
- **`publish`** — validate one authored durable artifact through
  [common guard](skill://forge/reference/common-guard.md), publish once using the selected
  recipe, and require native byte-preserving authored-source readback with only
  explicitly documented target normalization. Echoes and stored-body digests are
  not submitted-source equality. Known-created artifacts recover GET-only;
  unknown creation uses bounded reconciliation, never automatic repeat creation.
- **`act`** — run the ordered common guard, exactly one native mutation, then
  native post-read. Native protections/refusals are reported without bypass.
- **`post_merge_snapshot`** — read-only merged/linked-item state, result commit,
  containment, advisory result-bound CI and branch/worktree cleanup evidence.
  Queued is not merged; closure intent/preview are not observed item closure.

## Helpers

Resolve this skill's real installed filesystem directory through the runtime
resource resolver before executing `scripts/validate-text.mjs`; do not run
`node skill://...` or resolve helpers relative to target CWD. Its JSON envelope
validates exact string/finite role with no-body diagnostics before body-bearing
writes. Target safe-write tools may add native checks, not replace common checks.

```text
node <resolved-forge-dir>/scripts/validate-text.mjs --input <absolute-envelope.json>
```

Exact envelope: `{"role":"review-packet","content":"authored string"}` with only
those keys. Roles: `title`, `description`, `note`, `review-packet`, `receipt`,
`report`, `body`. Reject invalid/lossy UTF-8 decoding, malformed UTF-16, NUL,
non-whitespace C0 and DEL; allow tab/LF/CR and valid Unicode. Failures emit only
role/offset/type, never body or parser excerpts. Valid envelope content errors use
the supplied role and a UTF-16 content offset; envelope errors use `body`.

The selected target reference owns native identifiers/locators, tools, pagination,
normalization, closure syntax, draft/ready, receipt extraction, approval/finish,
expected-head guarantees and supported recovery. Shared records remain opaque;
explicit verified bindings, not string shape, establish trust. Ready pre/post
reads are observational unless the actual native operation guarantees atomicity;
exact-head finish/queue must be guaranteed by that operation or refused as
unsupported. Before finish re-read the recorded allocated open item and exact
change/source/item relationship. Verifier cleanup retains dirty, foreign,
unknown, unmerged and containment-unverified state.
