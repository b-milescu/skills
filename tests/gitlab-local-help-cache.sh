#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

skill="$REPO_ROOT/gitlab-local/SKILL.md"

require_text() {
  local needle="$1"
  grep -Fq "$needle" "$skill" || {
    echo "gitlab-local help-cache guidance missing: $needle" >&2
    exit 1
  }
}

require_text 'Before any flagged fallback `glab` command, run exact command help and verify every flag'
require_text 'Help-first remains mandatory for fallback `glab`'
require_text 'run-dir help cache'
require_text 'records the exact `glab <command> --help` output'
require_text 'verification status'
require_text 'Refresh the cache whenever the command, `glab` version, or repo context changes'

echo "gitlab-local-help-cache: PASS"
