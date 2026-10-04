# Common Mutation Guard

Every `forge act` and body-bearing `forge publish` runs this order. A failure
stops without trying another provider or transport:

1. provider/repository binding;
2. current target re-read;
3. reviewed commit binding when relevant;
4. advisory CI observation: attribute status only when bound to that commit or a native-proven integration candidate; absence, failure, or a binding mismatch is recorded and does not fail the guard;
5. exact-candidate local Gate Receipt when the action requires quality-gate evidence;
6. action-specific authority and provenance;
7. caller identity/context;
8. safe body validation when relevant;
9. provider-specific fallback eligibility;
10. exactly one mutation;
11. provider-native post-mutation re-read.

## Result contract

Return `passed`, `blocked`, `handoff`, `held`, or `escalated`; an opaque blocker
string or `none`; whether a mutation ran; selected provider/transport evidence;
and the post-read classification. Binding failure, stale head, missing or stale
Gate Receipt, missing authority, unsupported commit binding, or failed post-read
blocks without transport fallback. CI status never blocks the guard. A `held`
result (native protection, including a provider's required checks, holds the
mutation) is reported without bypass; once the hold clears, the retry is a new
`forge act` that re-runs every step from the first, and nothing from the held
attempt carries over.

The target's confirmed integration reference validates native identifiers and
locators; shared callers and validators preserve opaque values and verified scope.

## Snapshot evidence

`forge snapshot` is evidence-only. It enumerates, when available:

- decision-grade issue and change-request metadata, complete
  diff/discussion/review, exact-candidate Gate Receipt, and requested
  commit-bound advisory CI;
- change-request author id;
- Lift `claims` and missing rows;
- note-bound Review Report and Gate Receipt `claims` with author identity;
- the four head/author `bindings`: Lift reviewed SHA equals head, report
  reviewed SHA equals head, receipt commit equals head, and finding bindings
  match the report.

No routing field is added. `claims` and `bindings` are labelled as such; snapshot
never turns them into a decision, and its claims never replace native post-read.

Later action explanations are discovered through existing native
notes/discussions, not an added snapshot field or a future link in the immutable
Review Report. Consumers follow [Post-report action evidence](../../start-review/REVIEW-FLOW.md#post-report-action-evidence)
to verify report identity, exact reviewed commit, actor, and native outcome
evidence. Missing or mismatched action notes are evidence gaps, not proof that an
action succeeded or did not run.

## Authority Verification

Authority is action-specific and separate from transport evidence. Verify the
requested action, caller role/context, approval claim, finish claim, and source
provenance before any mutation. Explicit human or parent grants and restrictive
project policy take precedence over defaults; a builder claim never grants
authority, and silence never grants approval, merge, queue, release, cleanup, or
deploy authority. Conflicting, missing, restricted, unverifiable, identity-
changed, or self-finish evidence returns a blocker or handoff rather than trying
another transport. The target reference owns native approval/vote mechanics and
post-action readback.

Capture authenticated caller identity at entry in each required system scope and
retain it immutably; re-read immediately before writing. Missing/changed identity,
permission uncertainty or same-session self-review/self-finish stops the action.
Account equality alone does not establish session independence. Commit authors
and CI variables are not authenticated identity. Verify author/context separately.

Body publication requires exact string/role validation with the helper at
`../scripts/validate-text.mjs` (relative to this file), run by its resolved
absolute path rather than from the target CWD, before native checks. No diagnostic
may echo submitted body or parser excerpts. Require complete lossless native
readback against authored source; record only documented normalization.

If creation is known, retain its locator and recover GET-only. If its outcome is
unknown, reconcile bounded native reads without repeating creation; ambiguous or
absent matches require a human decision. Never silently repair submitted fields.
Receipt local validity, native extraction/candidate binding, and post-note
receipt/Lift validation are independent proofs.
