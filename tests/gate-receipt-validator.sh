#!/usr/bin/env bash
# Focus: Cross-platform pure-local Gate Receipt validator: accepts the
# canonical exact-SHA receipt; rejects
# missing/malformed/stale/prose-only/unsafe receipt and Reviewer Lift evidence
# without body leakage; rejects changed tracked files and any tracked-change
# waiver; proves Windows/UNC path plus CRLF handling; enforces pre-ready
# ordering; and keeps build/review cards and generated templates pointed at the
# canonical helper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec node "$REPO_ROOT/tests/gate-receipt-validator.mjs"
