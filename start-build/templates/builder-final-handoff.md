# Builder Final Handoff

Emit this block inline from child `mr-builder` sessions. Values contain no
secrets or private payloads. Consumers tolerate absence/malformed content and
fall back to the durable Review Packet plus provider-native readback.
Parent-owned fields follow `../reference/parent-owned-gate.md`.

Authority Verification claims use `skill://forge/reference/common-guard.md` for GitLab and the selected provider equivalent elsewhere.

Change-request locator: `<provider-native change-request locator>`
Durable note id: `<verified Gate Receipt note id, or not-created>`

Use the literal `not-created` when no receipt for this candidate exists. In
parent-owned mode this is the normal pre-gate return: leave the change request
Draft with its current candidate, complete Reviewer Lift, and parent-owned/not-run
contract. Do not invent an ID or post a note solely to fill this line. An existing
receipt is usable only after native readback verifies its candidate binding.
This locator contract does not implement or change builder-owned receipt policy.

Record `gate_owner_received` in the durable Review Packet beside the Reviewer
Lift, not as a third final line: echo the launch value, or `absent` when omitted.
The launch selection/default in [child-builder](../reference/child-builder.md#authority-boundary)
remains authoritative; this echo cannot select or change ownership.
Parents apply [stage-correct verification](../reference/parent-owned-gate.md#stage-correct-handoff-verification)
to native evidence, not the presence of a note ID.

Runtime notices are failures, not human stop tokens.
