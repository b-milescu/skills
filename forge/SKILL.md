---
name: forge
description: >-
  Select and operate the native transport for GitLab, GitHub, or Azure DevOps.
  Use whenever a workflow must bind a repository, read issue/change-request/CI
  evidence, publish a durable artifact, take a guarded action, or verify merged
  state across supported forges.
---

# Forge

This is a model-invoked transport seam. It selects the verified provider once,
then exposes five operations to generic workflows; generic callers do not branch on provider afterward.
They never load an unselected provider reference.

## Operations

1. **`preflight`** — bind the provider, canonical repository, default branch,
   readiness policy, authenticated identity, and optional bounded item discovery.
   Match the configured profile to normalized remotes. Unknown providers,
   ambiguous remotes, and profile/remote mismatches fail closed.
2. **`snapshot`** — return only the decision-grade issue, change-request,
   complete diff/discussion/review, exact-candidate Gate Receipt, requested
   commit-bound advisory CI evidence, change-request author id, Lift `claims`
   and missing rows, note-bound Review Report and Gate Receipt `claims` with
   author identity, and the four head/author `bindings`. Snapshot stays
   evidence-only; no routing field is added.
3. **`publish`** — validate and publish one safe durable artifact, then require
   provider-native byte-for-byte readback before reporting success. A durable
   artifact may be a tracker issue or work item (create + readback), not only a
   change-request or review-report update.
4. **`act`** — run the ordered [common guard](reference/common-guard.md), perform
   exactly one provider mutation, and classify its provider-native readback.
5. **`post_merge_snapshot`** — return read-only merged state, linked-item state,
   result commit, advisory result-commit CI, and branch-cleanup evidence.

## Provider disclosure

`preflight` discloses exactly one branch after binding:

- GitLab → [reference/gitlab.md](reference/gitlab.md)
- GitHub → [reference/github.md](reference/github.md)
- Azure DevOps → [reference/azure-devops.md](reference/azure-devops.md)

Provider references own native identifiers, status vocabularies, pagination,
draft/ready mechanics, comments or threads, advisory CI binding, approval or
vote semantics, native protection/refusal behavior, fallback eligibility,
closure rules, and readback. User-level verdict and action eligibility remain
provider-neutral. The common workflow sees opaque identifiers and locators only.
