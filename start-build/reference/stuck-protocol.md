# Stuck protocol

Detailed stuck-handling reference for `start-build`. This file is the canonical owner; [implementation-flow.md](implementation-flow.md) routes here.

If blocked for more than 2 hours:

1. Keep the change request in Draft.
2. Post `templates/stuck-packet.md` as a change-request comment after filling it with `forge publish`.
3. Apply the project's unblock label if one exists.
4. Request review explicitly for unblocking.
5. List ranked hypotheses.
6. Park the branch/worktree or switch to a non-blocked issue on a fresh branch/worktree.
