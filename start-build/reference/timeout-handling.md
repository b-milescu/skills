# Timeout handling

Detailed stale-run control reference for `start-build`. The stable entrypoint and compatibility anchor remain in [BUILD-FLOW.md](../BUILD-FLOW.md#timeout-handling).

A missing Review Report after the caller's review wait budget is only a stale-run signal. It does not by itself authorize a replacement reviewer.

**Wait on the completion event; do not poll.** The runtime notifies the gate owner when a spawned child completes — foreground runs block until they return, background runs signal completion. Re-reading a child's run, re-invoking it to "check in", or repeatedly fetching its status while it is still active spends context for no new signal; rely on the completion notification. Inspect run status only when the wait budget elapses with no completion, or a concrete anomaly (error, crash, contradictory partial output) appears.

Before replacing a reviewer attempt:

1. Check observed reviewer status/activity through the runtime's status/control/interruption mechanism when that mechanism is available. Prefer direct run state, recent output, heartbeat/progress markers, or completion/failure status over elapsed time.
2. If the runtime exposes control/interrupt, interrupt only a run that is failed, stale, blocked, paused, or otherwise not making progress. Do not interrupt or replace a reviewer that is still active.
3. If status/control is unavailable, unreachable, or ambiguous, escalate instead of launching a duplicate reviewer. Record what could not be observed.
4. Record the reason before any second reviewer attempt. A second reviewer attempt is allowed only after the first attempt is failed, stale, interrupted, or unreachable with the reason documented.
5. If the second reviewer attempt also becomes failed, stale, interrupted, or unreachable, escalate to human with both attempt records and no approval/merge claim.
