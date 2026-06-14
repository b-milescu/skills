# Standalone review gate

Detailed mandatory review gate for standalone `/start-build` sessions. Stable compatibility anchors remain [BUILD-FLOW.md §Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate), [§Reviewer launch protocol](../BUILD-FLOW.md#reviewer-launch-protocol), [§Timeout handling](../BUILD-FLOW.md#timeout-handling), [§Review Gate Summary](../BUILD-FLOW.md#review-gate-summary), and [§Human bypass protocol](../BUILD-FLOW.md#human-bypass-protocol). Child `mr-builder` sessions do not own this gate; their small path is [child-builder.md](child-builder.md).

## Mandatory review gate

In standalone `/start-build` mode, the builder owns reviewer handoff and must start a fresh reviewer through whatever orchestration mechanism the runtime provides; this gate is mandatory, not optional. If that runtime has no reviewer-launch mechanism, stop and report the blocker instead of self-reviewing. In child `mr-builder` mode, the parent orchestrator owns this gate after the child returns its final handoff; the child builder must not start a reviewer unless explicitly instructed. The builder never self-approves or self-merges. Builder and reviewer may share the same GitLab username/PAT — review independence comes from session/context separation, not GitLab identity. Concrete parent-managed discovery guidance lives in [parent-orchestrator.md](parent-orchestrator.md), not in child-builder instructions.

## Note-deliverable review path

The mandatory review gate above is **MR-centric**, and the MR path is the **default for any code or docs-in-repo change**. Some issues have no repo change at all: an **analysis-only `kind:meta` issue** whose deliverable is a **tracker note** (an audit, a retro finding, a research summary recorded as a GitLab issue note) rather than a commit. For that case the artifact is the note, so there is no MR to spawn `start-review` on, and the gate takes the note-deliverable shape below.

**When this path applies (and only then):**

- The issue is analysis-only `kind:meta` (or the project's equivalent no-code analysis kind), and
- the deliverable is a tracker note, **not** a repo change. Any code or docs-in-repo change — including documentation committed to the repository — stays on the **default MR path** and its MR-centric gate. When an issue mixes a note with a repo change, the repo change goes through an MR; do not use the note path to skip MR review for committed changes.

**The gate (note-deliverable shape):**

- **Artifact** = the tracker note posted to the issue.
- **Gate** = a **fresh independent reviewer** verifies the note against the issue acceptance criteria — citations resolve, `Refs:` / redaction present, no overclaim, and acceptance-criteria coverage — **plus** a Review Gate Summary recorded on the issue (use the same [Review Gate Summary](#review-gate-summary) shape, posted as an issue note instead of an MR comment).

**Preserved invariants (verbatim, not relaxed).** The note path **adds** a gate where none was previously defined; it never weakens one. The following floors hold exactly as on the MR path:

- **Mandatory independent review.** The note is reviewed by a fresh independent reviewer session; this gate is mandatory, not optional, and review independence comes from session/context separation (the builder and reviewer may share the same GitLab identity).
- **No builder self-approval.** The builder must not approve its own note deliverable or sign off on its own Review Gate Summary; the verdict comes from the independent reviewer.
- **Context Firewall intact.** The reviewer does not treat builder/parent reasoning as evidence; the builder's note prose and handoff are a map to verify against the issue acceptance criteria, not truth.

A reader must not mistake the no-MR note path for a relaxed gate: it is the same independent-review floor applied to a note artifact.

**Worked example.** The exampleproject `#314` `/start-build` batch was a `kind:meta`, no-code analysis issue whose deliverable was the `#188` tracker note (no MR). The builder improvised exactly this shape — a fresh independent reviewer over the note verifying citations resolve, redaction, no overclaim, and acceptance-criteria coverage, plus a Review Gate Summary recorded on the issue. The review passed and caught 2 nits, confirming the independent-review pattern works on a note artifact. This section documents that pattern as first-class so subsequent `kind:meta` no-code issues do not re-improvise it.

## Reviewer launch protocol

When you own this gate after the MR is ready:

1. **Discover available reviewers** using the runtime-specific agent discovery mechanism available to the owner of the gate. Look for agents whose name or description indicates MR / code-review specialization, for example `mr-reviewer`, `gitlab-reviewer`, or a project-scope `reviewer` override. Prefer project-scope agents over user-scope agents over builtin reviewers. If a specialized MR reviewer is found, use it; otherwise fall back to the builtin reviewer.
2. **Start** the selected reviewer running `start-review` in a fresh session. The task prompt is a minimal reviewer launch prompt and must include only the review target and evidence-boundary instructions:
   - **MR URL** — the full GitLab MR web URL.
   - **Reviewer Lift pointer** — direct the reviewer to the Reviewer Lift block in the MR description so it can copy structured values into the Review Report.
   - **Project rulebook path** — the path to the project's `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or equivalent rulebook so the reviewer can evaluate against project-specific rules.
   - **Context Firewall instruction** — tell the reviewer not to treat parent/builder reasoning as evidence; Reviewer Lift and handoff prose are a map to verify, not truth.
   - **Granted merge authority (conditional — include only when granted)** — when merge authority for this MR was granted to the orchestrator (for example a human `merge`/release directive in the `/start-build` session), relay it in the launch prompt as an explicit **orchestrator/parent merge-authority grant**: name the granted value (`reviewer may merge`, `queue auto-merge`, etc.) and the **source provenance** (the human/parent instruction that granted it). The relayed grant is an accepted `parent task prompt` (`parent-explicit`) source per [authority-verification.md](../../gitlab/reference/authority-verification.md), giving the fresh reviewer a reviewer-verifiable merge-authority source for SHA-guarded finish in the same session instead of blocking finish `missing-authority`. Omit this field entirely when no merge authority was granted. The relayed grant is a verifiable authority source; the builder-authored Reviewer Lift `Merge authority` field remains a claim to verify, not permission to skip verification.

Relaying a granted authority is **carved out of the minimal-prompt rule**: that rule forbids passing builder/parent **reasoning** as evidence about the code, but an orchestrator-relayed **authority grant** is not builder reasoning — it is a verifiable source the reviewer checks through [Authority Verification](../../gitlab/reference/authority-verification.md) before any finish action. The reviewer reads the relayed grant as the verifiable merge-authority source the builder-authored Reviewer Lift `Merge authority` field cannot be, not as permission to skip verification.

**Floor preservation (explicit, unchanged).** Independent review still runs in a fresh session; the authority still **originates from the human** (the orchestrator relays it, the builder does not mint it); the finisher is the **independent reviewer, not the builder**; and the SHA/CI/approval guards plus the no-builder-self-merge rule are unchanged. This documents the relay *channel* standalone mode already implies; it does not grant new authority.

For the canonical example task prompt template and the planning-details exclusion rule — including the minimal-prompt carve-out that permits this orchestrator-relayed authority grant — see [parent-orchestrator.md §Minimal reviewer launch prompt](parent-orchestrator.md#minimal-reviewer-launch-prompt).

## Review loop

1. **Start** a fresh reviewer session.
2. **Wait** for the Review Report using the caller's review wait budget. No fixed wall-clock value alone authorizes replacement; if the report is missing after the budget, follow [Timeout handling](#timeout-handling) before any second reviewer attempt.
3. **Evaluate** the reviewer's decision:
   - **Pass** — the reviewer's verdict is `pass`; this is a review judgment only and never by itself implies approval or merge. On a `pass` verdict, the reviewer records the separate approval action for the reviewed SHA when approval authority permits it, then finishes per separate `Merge authority`. If merge authority is `approval-only` or `human release`, stop after approval and report the reviewed SHA. If merge authority is `reviewer may merge` or `queue auto-merge`, only the reviewer, an authorized parent, or a human may merge or queue with the reviewed SHA. When merge authority is already granted, the approving reviewer performs the SHA-guarded finish in this same session only when the grant reached the reviewer through the launch prompt as a reviewer-verifiable source (see [Reviewer launch protocol](#reviewer-launch-protocol)); spawn a separate authorized finisher only when merge authority arrives after the review session has ended. If GitLab blocks reviewer-side merge or queue, report the blocker and route finish to an authorized parent or human; the builder must not merge as a fallback. For safety-critical tasks, link the MR from any durable decision log the project keeps. Record the reviewed SHA and decision.
   - **Request changes** — push fix commits, each commit subject naming the item ID such as `MF-1: <fix>`; post a revision-packet comment; update the MR description and Reviewer Lift; then start a **new** reviewer session with fresh context.
   - **Reject** — hard stop. Do not spawn another reviewer on the same MR. Escalate to human immediately.
   - **Blocked** — the reviewer could not complete the review (for example a final guard failed, evidence was missing, or a non-code blocker stopped the review). Do not treat a `blocked` verdict as approval or finish; record the blocker, do not spawn another reviewer on the same MR for the same blocker, and escalate to human.
4. **3-round limit:** up to 3 rounds total, initial plus 2 retries. If all 3 rounds result in request-changes, escalate to human with round count, Review Reports, and remaining Must Fix items.

## Timeout handling

Detailed timeout handling lives in [timeout-handling.md](timeout-handling.md). Core policy: missing Review Report after the wait budget is a stale-run signal, not review completion. Check observed status/activity through the runtime's status/control/interruption mechanism when available, interrupt or replace only failed/stale/interrupted/unreachable runs with a documented reason, escalate instead of launching a duplicate reviewer when status/control is unavailable or ambiguous, and never replace a reviewer that is still active.

## Review Gate Summary

After all rounds complete or escalation is needed, post a brief summary as an MR comment:

```markdown
## Review Gate Summary

| Round | Reviewer | Decision | Headline |
|-------|----------|----------|----------|
| 1     | <agent>  | pass / request-changes / reject / blocked / timeout / stale / interrupted | <one-line summary> |
| 2     | <agent>  | ...      | ...      |
| 3     | <agent>  | ...      | ...      |

Final Review Report: <link to MR comment, or N/A — timeout/stale/interrupted without completed report>
```

The `Decision` column records the reviewer's round verdict (`pass`, `request-changes`, `reject`, or `blocked`), not the approval side effect. A `pass` verdict is a review judgment only; the approval action is recorded separately and never implied by the verdict.

`timeout / stale / interrupted are non-completion states`: they document gate history and escalation blockers only. They do not imply independent review completed, approval exists, or finish authority is available.

## Human bypass protocol

A human can bypass the mandatory review gate, but only through an unmistakable, non-inferable instruction. The bypass must never be inferred from paraphrase, tone, or general release enthusiasm. All of the following conditions must hold:

- **Strict accepted bypass phrase.** The human used one of the exact accepted bypass phrases **"skip gate"** or **"merge unreviewed"** with clear intent to waive review for this MR. This accepted-phrase set is closed: a phrase counts only when it matches one of these literals (case-insensitive), not when it merely resembles them. There is no "or equivalent" escape hatch — paraphrase does not bypass.
- **Ambiguous release language does not bypass.** Vague approval/release phrases such as **"ship it"**, **"looks fine"**, **"lgtm"**, "go ahead", or "send it" do not bypass review, even when said by the human. Ambiguous release language must be clarified before any bypass: ask the human to either restate using an accepted bypass phrase or confirm that normal review applies. When in doubt, the gate stays mandatory.
- **Named actor.** The waiver names the human or human-authorized actor who issued it; the named human (or authorized actor) must be identifiable, and an anonymous or assumed-on-someone's-behalf bypass is invalid.
- **Recorded reason.** The override reason is documented in the MR description.
- **`Review gate` field.** The MR description `Review gate` Reviewer Lift field is set to `bypassed (human override)`.
- **Audit trail.** The accepted phrase, named actor, and reason are recorded in an MR comment so an auditor can later see who bypassed, why, and where it is recorded.

A bypass does not waive the safety invariant against builder self-approval — even with a bypass, the builder still must not approve or merge its own MR. The human performs the merge directly or authorizes a named agent to do so.
