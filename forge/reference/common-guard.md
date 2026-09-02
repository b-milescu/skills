# Common Mutation Guard

Every `forge act` and body-bearing `forge publish` runs this order. A failure
stops without trying another provider or transport:

1. provider/repository binding;
2. current target re-read;
3. reviewed commit binding when relevant;
4. advisory CI observation: attribute status only when bound to that commit or a provider-proven integration candidate; absence, failure, or a binding mismatch is recorded and does not fail the guard;
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
Gate Receipt, missing authority, unsafe body, unsupported commit binding, or
failed post-read blocks without transport fallback. CI status never blocks.

Provider branches validate native identifier and locator shapes. Shared callers
and validators preserve their values as opaque strings.

## Authority Verification

Authority is action-specific and separate from transport evidence. Verify the
requested action, caller role/context, approval claim, finish claim, and source
provenance before any mutation. Explicit human or parent grants and restrictive
project policy take precedence over defaults; a builder claim never grants
authority, and silence never grants approval, merge, queue, release, cleanup, or
deploy authority. Conflicting, missing, restricted, unverifiable, identity-
changed, or self-finish evidence returns a blocker or handoff rather than trying
another transport. Provider branches own native approval/vote mechanics and
post-action readback.
