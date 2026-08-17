#!/usr/bin/env bash
set -euo pipefail

# Enforces executable-bit policy documented in docs/agents/check-gate.md
# §Executable-bit policy: tracked file mode 100755 is allowed only for
# directly invoked entrypoints `install.sh` and `scripts/check.sh`.
# Every other tracked
# shell/helper file must stay 100644.
#
# The guard reads `git ls-files -s` (the git index mode), not filesystem
# permissions, so a CI checkout that drops or adds execute bits on disk cannot
# mask drift in the committed tree.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# is_allowed_executable PATH -> exit 0 path may be 100755.
# Allowlist the two documented direct entrypoints only.
is_allowed_executable() {
 local path="$1"
 case "$path" in
 install.sh) return 0 ;;
 scripts/check.sh) return 0 ;;
 *) return 1 ;;
 esac
}

# check_repo REPO -> prints violators (mode + path) and returns non-zero when any
# tracked 100755 file falls outside the documented allowlist.
check_repo() {
  local repo="$1"
  local violations_file="$TMPDIR/violations.$$.txt"
  : > "$violations_file"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # `git ls-files -s` format: "<mode> <sha> <stage>\t<path>"
    local mode path
    mode="${line%% *}"
    path="${line#*$'\t'}"
    [[ "$mode" == "100755" ]] || continue
    if ! is_allowed_executable "$path"; then
      printf '  %s %s\n' "$mode" "$path" >> "$violations_file"
    fi
  done < <(git -C "$repo" ls-files -s)

  if [[ -s "$violations_file" ]]; then
    echo "Executable-bit policy violation: tracked files with mode 100755 outside the allowlist" >&2
 echo "(allowed: install.sh, scripts/check.sh; everything else must be 100644):" >&2
    cat "$violations_file" >&2
    return 1
  fi
  return 0
}

# --- Fail-closed self-tests on disposable fixture repos -------------------------
# These prove the guard cannot fail open: a stray executable outside the three
# documented patterns must FAIL, and the documented entrypoints must PASS.

make_fixture_repo() {
  local repo="$1"
  shift
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email fixture@example.com
  git -C "$repo" config user.name fixture
  local spec mode path
  for spec in "$@"; do
    mode="${spec%%:*}"
    path="${spec#*:}"
    mkdir -p "$repo/$(dirname "$path")"
    printf '#!/usr/bin/env bash\n' > "$repo/$path"
    git -C "$repo" add "$path"
    git -C "$repo" update-index --chmod="$([[ "$mode" == "100755" ]] && echo +x || echo -x)" "$path"
  done
}

assert_repo_fails() {
  local repo="$1" needle="$2" desc="$3"
  set +e
  local out status
  out="$(check_repo "$repo" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    echo "fail-closed self-test failed: $desc should have been rejected but passed" >&2
    exit 1
  fi
  if [[ "$out" != *"$needle"* ]]; then
    echo "fail-closed self-test failed: $desc missing expected diagnostic for $needle" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
}

assert_repo_passes() {
  local repo="$1" desc="$2"
  set +e
  local out status
  out="$(check_repo "$repo" 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    echo "fail-closed self-test failed: $desc should have passed but was rejected" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
}

# A stray executable test script must fail (the exact drift this guard prevents).
stray_test_repo="$TMPDIR/stray-test"
make_fixture_repo "$stray_test_repo" \
  100644:install.sh 100755:tests/regression.sh
assert_repo_fails "$stray_test_repo" "tests/regression.sh" "executable tests/*.sh"

# executable non-allowlisted helper path must fail.
legacy_helper_repo="$TMPDIR/legacy-helper"
make_fixture_repo "$legacy_helper_repo" 100755:scripts/helper.sh
assert_repo_fails "$legacy_helper_repo" "scripts/helper.sh" "executable non-allowlisted helper"


# executable outside allowlist (e.g. new top-level script) must fail —
# allowlist may not open new executables.
stray_root_repo="$TMPDIR/stray-root"
make_fixture_repo "$stray_root_repo" 100755:scripts/extra.sh
assert_repo_fails "$stray_root_repo" "scripts/extra.sh" "executable outside allowlist"

# only the two documented entrypoints pass.
allowed_repo="$TMPDIR/allowed"
make_fixture_repo "$allowed_repo" \
 100755:install.sh \
 100755:scripts/check.sh \
 100644:tests/regression.sh
assert_repo_passes "$allowed_repo" "documented entrypoints"

# --- Real repository check ------------------------------------------------------
check_repo "$REPO_ROOT"

echo "executable-bit policy: PASS"
