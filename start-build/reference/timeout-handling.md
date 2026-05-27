# Timeout handling

Detailed review-timeout reference for `start-build`. The stable entrypoint and compatibility anchor remain in [BUILD-FLOW.md](../BUILD-FLOW.md#timeout-handling).

If no Review Report comes back within 10 minutes:

1. Do not retry the same reviewer session — it may be hung.
2. Start one fresh reviewer session with the same task prompt.
3. If the second attempt also times out, escalate to human.
