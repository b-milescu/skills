# Common Mutation Guard

Every `forge act` and body-bearing `forge publish` runs this order. A failure
stops without trying another provider or transport:

1. provider/repository binding;
2. current target re-read;
3. reviewed commit binding when relevant;
4. advisory CI observation: attribute status only when bound to that commit or a native-proven integration candidate; absence, failure, or a binding mismatch is recorded and does not fail the guard;
5. when the action requires quality-gate evidence, read the complete [receipt proof mechanics](../../start-build/reference/gate-receipt.md) and verify the exact-candidate local Gate Receipt, including current [execution-context binding](../../start-build/reference/parent-owned-gate.md#execution-context-binding-and-reuse);
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
Gate Receipt, missing authority, unsupported commit binding, a packet over a
known applicable [packet home](../SKILL.md#packet-home) limit, or failed post-read
blocks without transport fallback. CI status never blocks the guard.

A `held` result means native protection, including a provider's required checks,
prevented the mutation. Report it without bypass. For pending required checks,
follow the mandatory
[wait contract](../../start-build/reference/parent-orchestrator.md#required-check-wait-budget).
Once the hold clears, the retry is a new `forge act`: restart every ordered phase
from the first; no guard result carries over, including head, authenticated actor
or action-grant validation. Deny an ineligible mutation rather than resuming at
the write step. A held merge ran no mutation, so its guarded retry remains the
one authorized finish action.

The target's confirmed integration reference validates native identifiers and
locators; shared callers and validators preserve opaque values and verified scope.

## Snapshot evidence

`forge snapshot` is evidence-only. It enumerates, when available:

- decision-grade issue and change-request metadata, complete
  diff/discussion/review, exact-candidate Gate Receipt, and requested
  commit-bound advisory CI;
- change-request author id;
- Lift `claims` and missing rows, read at the [packet home](../SKILL.md#packet-home);
- note-bound Review Report and Gate Receipt `claims` with author identity;
- the four head/author `bindings`: Lift reviewed SHA equals head, report
  reviewed SHA equals head, receipt commit equals head, and finding bindings
  match the report.

Resolve the current selected packet through the [packet-home contract](../SKILL.md#packet-home)
for discovery, gate/Lift rebind and review. For note homes, use only the current
description pointer with native same-change and current-head binding; historical
notes or copied report markers never select a candidate. Missing, stale,
wrong-change or head-mismatched pointers block affected transitions. Validate one
Lift block within that selected packet, not across historical packet/report notes.

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

## Native validation

An undocumented ceiling/unit permits one otherwise authorized ordinary
publication only under a dependable target-native validation/readback recipe.
Establish and validate it for the active operation from a recorded target recipe
or bound current documentation under [operation-time recipes](../SKILL.md#operation-time-recipes).
Before writing, establish dependable mechanics to bind the actual native artifact,
authenticated actor and destination scope, recover the complete string-valued
native body, and compare it to the retained pre-write authored source. A schema
body-read field alone proves none of this; missing proof blocks before writing.
Record possible refusal, unverified artifacts and manual recovery, not unlimited
capacity. Never probe a ceiling, truncate, split or silently switch home/transport.
Proven readback capability does not replace the actual native post-read.

Body publication requires exact string/role validation with the helper at
`../scripts/validate-text.mjs` (relative to this file), run per the
[helper rule](../SKILL.md#helpers), before native checks. Retain the complete
pre-write authored source and submit exactly that string. Enforce applicable
authoritative bounds in their known units; undocumented capacity follows only
the native-validation recipe above, not a guessed cap. No diagnostic may echo
submitted body or parser excerpts. Require a complete string-valued native body,
actual artifact/destination/actor binding and comparison against that retained
original. Compare byte-for-byte unless the target explicitly permits a documented
normalization, which must be reported and independently confirmed; a normalized
match is not byte-for-byte equality. Keep the authored source unchanged.

`forge` owns publication verification. Reuse the selected, documented safe-write
recipe's existing native post-read evidence only for guarantees it actually
establishes: complete native readback, submitted-source comparison,
artifact/destination/actor binding, allowed normalization and fail-closed
mismatch/recovery. Complementary results may jointly establish these guarantees
only when bound to the same actual artifact and retained intent. Missing fields
are unknown, not safe defaults. Derive expected hashes/counts independently from
the retained source, applying only the explicitly allowed normalization; a write's
stored-body digest, echo or generic success flag is not source proof.

Keep local source/envelope validation and target-specific checks the native
writer does not implement. Within that publication, do not repeat native reads,
comparisons or validator invocations for guarantees already established; obtain
only missing required evidence. A complete body returned by an internal native
GET may be retained directly as the readback file without refetching it.
CLI/plain writes and recipes without equivalent proof still require explicit
native GET and source comparison. Stricter target policy continues to govern
until its recipe is aligned; this reusable contract alone ships no downstream
adoption or measured savings.

Reuse does not replace a later actor's independent verification or fresh-state
reads for ready, review, approval, finish or post-merge decisions. Refusal,
missing/null body, mismatch, unavailable required evidence or uncertain outcome
leaves publication unverified and blocks dependent ready/review/finish.

If creation is known, retain its locator and recover GET-only. If its outcome is
unknown, use one bounded read-only native reconciliation without repeating
creation; an error is not proof of rollback. Bind this run's new artifact using
the target's native correlation or pre-write artifact evidence. An old artifact
is never this run's publication merely because author, head, time or even body
bytes match. Absent, ambiguous or incomplete evidence requires a human decision;
never silently repair submitted fields. Receipt local validity, native
extraction/candidate binding and post-note receipt/Lift validation are independent
proofs.

## Exact-head guarantees

Ready pre/post reads are observational unless the actual native operation
guarantees atomicity. Exact-head finish/queue must be guaranteed by that operation
or refused as `sha-bound-action-unsupported`. A direct merge needs documented
stale-head rejection in the target recipe or bound current documentation, or
recorded evidence from an explicitly authorized [disposable stale-head probe](#disposable-stale-head-probe).
A request field or schema alone is not proof. Queue binding must hold through
actual merge, not just request acceptance; unsupported or unproven binding is
refused with no unbound fallback or direct merge under queue authority.

### Disposable stale-head probe

Where direct-merge rejection is undocumented, obtain explicit probe and cleanup
authority; neither setup nor recipe resolution grants it. An authorized actor
creates disposable source and target branches and a disposable change request,
never protected/shared branches. Capture the old full head, advance the disposable
source to a new full head, then request the selected native direct merge bound to
the **old** head. Require stale-head refusal and an unmerged native post-read.
Accepted or unproven outcomes leave exact-head direct merge unsupported.

Record date, native change/request locator and authenticated identity, both full
SHAs, refusal status/response and unmerged post-read in the target reference.
After recording, the authorized actor closes/deletes the disposable artifacts
under the explicit cleanup grant. A documented stale-head rejection guarantee
needs no live probe.

