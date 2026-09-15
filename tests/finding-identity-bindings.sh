#!/usr/bin/env bash
# Focus: Pure-local canonical finding identity validator: two Review Reports
# may both define `MF-5` while `(Report locator, Reviewed SHA, Finding ID)`
# tuples remain distinct; valid Revision Packet and Reviewer Lift bindings
# pass; bare/missing/stale/contradictory bindings fail before
# publication/ready; LF and CRLF inputs produce the same result through
# platform-neutral Node path handling and no network calls.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "$ROOT_DIR/tests/finding-identity-bindings.mjs"
