# Builder Final Handoff

Emit this block inline from child `mr-builder` sessions. Values contain no
secrets or private payloads. Consumers tolerate absence/malformed content and
fall back to the durable Review Packet plus provider-native readback.
Parent-owned fields follow `../reference/parent-owned-gate.md`.

Authority Verification claims use `skill://forge/reference/common-guard.md` for GitLab and the selected provider equivalent elsewhere.

Change-request locator: `<provider-native change-request locator>`
Durable note id: `<Gate Receipt note id for a parent-gated builder run>`

Runtime notices are failures, not human stop tokens.
