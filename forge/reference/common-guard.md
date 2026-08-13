# Common Mutation Guard

Every `forge act` and body-bearing `forge publish` runs this order. A failure
stops without trying another provider or transport:

1. provider/repository binding;
2. current target re-read;
3. reviewed commit binding when relevant;
4. CI evidence bound to that commit or a provider-proven integration candidate;
5. action-specific authority and provenance;
6. caller identity/context;
7. safe body validation when relevant;
8. provider-specific fallback eligibility;
9. exactly one mutation;
10. provider-native post-mutation re-read.

## Result contract

Return `passed`, `blocked`, `handoff`, `held`, or `escalated`; an opaque blocker
string or `none`; whether a mutation ran; selected provider/transport evidence;
and the post-read classification. Binding failure, stale head, unbound/red/
missing required CI, missing authority, unsafe body, unsupported commit binding,
or failed post-read blocks without transport fallback.

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
