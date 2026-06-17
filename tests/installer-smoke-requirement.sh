#!/usr/bin/env bash
# Regression guard: installer smoke requirement docs stay present in check-gate.md.
# Fails if the requirement text is removed, so the rule cannot silently disappear.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { echo "FAIL: $1" >&2; exit 1; }

require_text() {
  local file="$1" pattern="$2" desc="$3"
  if ! grep -qE "$pattern" "$file"; then
    fail "missing $desc in $file"
  fi
}

check_gate_doc="docs/agents/check-gate.md"

# Section heading must exist
require_text "$check_gate_doc" 'Installer smoke requirement' \
  'Installer smoke requirement section heading'

# install_surface surface must be named as required
require_text "$check_gate_doc" 'install_surface' \
  'install_surface surface required for agent/installer changes'

# agents/ must be a named trigger path
require_text "$check_gate_doc" 'agents/' \
  'agents/ path trigger in installer smoke section'

# install.sh + runtime agent routing must be named as trigger surfaces
require_text "$check_gate_doc" 'runtime agent routing' \
  'runtime agent routing trigger in installer smoke section'

# Schema-checks-alone must be stated as insufficient
require_text "$check_gate_doc" 'cannot be satisfied' \
  'schema-checks-not-sufficient language in installer smoke section'

# temp-HOME installer smoke must be the required evidence form
require_text "$check_gate_doc" 'HOME=<tmpdir>' \
  'temp-HOME installer smoke evidence in installer smoke section'

# Parent-owned gate evidence must name installer smoke when install_surface is present
require_text "$check_gate_doc" 'parent-owned gate evidence' \
  'parent-owned gate evidence requirement in installer smoke section'

# install_surface must be mentioned in the parent-owned gate evidence context
require_text "$check_gate_doc" 'install_surface.*present|present.*install_surface' \
  'install_surface presence condition for parent-owned gate evidence'

# Shared MR route symlink ownership must be stated in install-symlink-ownership description
require_text "$check_gate_doc" 'install-symlink-ownership.*shared MR route|shared MR route.*install-symlink-ownership' \
  'shared MR route symlink ownership coverage in install-symlink-ownership inventory entry'

# installer-smoke-requirement test must itself be in the check-gate inventory
require_text "$check_gate_doc" 'tests/installer-smoke-requirement\.sh' \
  'installer-smoke-requirement test in check-gate inventory'

printf 'installer-smoke-requirement: PASS\n'
