#!/usr/bin/env bash
# Focus: Check Gate shipped shell regression inventory stays synchronized with
# tracked `tests/*.sh` files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

write_check_gate_doc() {
  local repo="$1"
  shift

  mkdir -p "$repo/docs/agents"
  {
    printf '# Check Gate\n\n'
    printf '## Shipped shell regression inventory\n\n'
    printf '`scripts/check.sh` runs every top-level `tests/*.sh` file. Keep this inventory synchronized when adding, removing, or renaming a shell regression script.\n\n'
    printf '| Script |\n'
    printf '| --- |\n'
    local script
    for script in "$@"; do
      printf '| `%s` |\n' "$script"
    done
    printf '\n## Next Section\n\n'
  } > "$repo/docs/agents/check-gate.md"
}

extract_inventory_scripts() {
  local repo="$1"
  local doc="$repo/docs/agents/check-gate.md"

  awk '
    /^## Shipped shell regression inventory$/ { in_section=1; next }
    in_section && /^## / { exit }
    in_section && /^\| `tests\/[^`\/]+\.sh`[[:space:]]*\|/ {
      path=$0
      sub(/^\| `/, "", path)
      sub(/`.*/, "", path)
      print path
    }
  ' "$doc" | sort
}

list_executed_test_scripts() {
  # Discover the same surface the scripts/check.sh test loop actually executes: the
  # top-level tests/*.sh disk glob. Keying on disk presence (not git ls-files)
  # catches a new test that is present but unregistered before it is committed,
  # so the local gate fails identically to CI (issue gitlab#326). tests/lib/** helper
  # modules stay excluded because the glob is non-recursive and top-level only.
  local repo="$1"
  (
    cd "$repo" || exit 1
    shopt -s nullglob
    local path
    for path in tests/*.sh; do
      printf '%s\n' "$path"
    done
  ) | awk '/^tests\/[^\/]+\.sh$/ { print }' | sort
}

check_inventory() {
  local repo="$1"
  local actual_file="$TMPDIR/actual.$(basename "$repo").txt"
  local inventory_file="$TMPDIR/inventory.$(basename "$repo").txt"
  local missing_file="$TMPDIR/missing.$(basename "$repo").txt"
  local extra_file="$TMPDIR/extra.$(basename "$repo").txt"

  list_executed_test_scripts "$repo" > "$actual_file"
  extract_inventory_scripts "$repo" > "$inventory_file"

  comm -23 "$actual_file" "$inventory_file" > "$missing_file"
  comm -13 "$actual_file" "$inventory_file" > "$extra_file"

  if [[ -s "$missing_file" || -s "$extra_file" ]]; then
    echo "Check Gate shipped shell regression inventory is out of sync with top-level tests/*.sh files present on disk." >&2
    if [[ -s "$missing_file" ]]; then
      echo "Missing from docs/agents/check-gate.md inventory:" >&2
      sed 's/^/  - /' "$missing_file" >&2
    fi
    if [[ -s "$extra_file" ]]; then
      echo "Inventory entries with no tests/*.sh file present on disk:" >&2
      sed 's/^/  - /' "$extra_file" >&2
    fi
    exit 1
  fi

  # docs/agents/check-gate.md keeps no per-script prose; it delegates coverage
  # to a `# Focus:` header directly below each shebang (issue gitlab#463). Enforce
  # that placement and non-empty text so the convention is a check, not trust.
  local headerless_file="$TMPDIR/headerless.$(basename "$repo").txt"
  local path
  : > "$headerless_file"
  while read -r path; do
    if [[ "$(sed -n '2p' "$repo/$path")" != '# Focus:'*[![:space:]]* ]]; then
      printf '%s\n' "$path" >> "$headerless_file"
    fi
  done < "$actual_file"

  if [[ -s "$headerless_file" ]]; then
    echo "Top-level tests/*.sh scripts must state their coverage in a non-empty '# Focus:' header comment directly below the shebang." >&2
    sed 's/^/  - /' "$headerless_file" >&2
    exit 1
  fi
}

make_fixture_repo() {
  local repo="$1"
  shift

  mkdir -p "$repo/tests"
  git -C "$repo" init -q
  local script
  for script in "$@"; do
    mkdir -p "$repo/$(dirname "$script")"
    printf '#!/usr/bin/env bash\n' > "$repo/$script"
    git -C "$repo" add "$script"
  done
}

missing_repo="$TMPDIR/missing-entry"
mkdir -p "$missing_repo"
make_fixture_repo "$missing_repo" tests/actual.sh tests/missing-from-doc.sh tests/lib/helper.sh
write_check_gate_doc "$missing_repo" tests/actual.sh
set +e
missing_output="$(check_inventory "$missing_repo" 2>&1)"
missing_status=$?
set -e
if [[ $missing_status -eq 0 || "$missing_output" != *"tests/missing-from-doc.sh"* ]]; then
  echo "missing tracked script fixture did not fail with expected diagnostic" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$missing_output" >&2
  exit 1
fi
if [[ "$missing_output" == *"tests/lib/helper.sh"* ]]; then
  echo "helper module fixture was incorrectly treated as a top-level regression script" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$missing_output" >&2
  exit 1
fi

extra_repo="$TMPDIR/extra-entry"
mkdir -p "$extra_repo"
make_fixture_repo "$extra_repo" tests/actual.sh
write_check_gate_doc "$extra_repo" tests/actual.sh tests/not-tracked.sh
set +e
extra_output="$(check_inventory "$extra_repo" 2>&1)"
extra_status=$?
set -e
if [[ $extra_status -eq 0 || "$extra_output" != *"tests/not-tracked.sh"* ]]; then
  echo "non-existent inventory entry fixture did not fail with expected diagnostic" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$extra_output" >&2
  exit 1
fi

untracked_repo="$TMPDIR/untracked-present-entry"
mkdir -p "$untracked_repo"
make_fixture_repo "$untracked_repo" tests/actual.sh
write_check_gate_doc "$untracked_repo" tests/actual.sh
# A new top-level test present on disk but neither tracked nor listed in the
# inventory: this is exactly what the scripts/check.sh test loop would execute, so the
# inventory check must flag it before commit (it is the bug under issue gitlab#326).
printf '#!/usr/bin/env bash\n' > "$untracked_repo/tests/untracked-present.sh"
set +e
untracked_output="$(check_inventory "$untracked_repo" 2>&1)"
untracked_status=$?
set -e
if [[ $untracked_status -eq 0 || "$untracked_output" != *"tests/untracked-present.sh"* ]]; then
  echo "untracked-present script fixture did not fail with expected diagnostic" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$untracked_output" >&2
  exit 1
fi

# In-sync inventories still fail when a tracked top-level script does not state
# its own coverage: docs/agents/check-gate.md delegates the per-script
# description to a `# Focus:` header directly below the shebang (issue gitlab#463),
# so the gate has to enforce that convention rather than trust it.
header_missing_repo="$TMPDIR/header-missing"
mkdir -p "$header_missing_repo"
make_fixture_repo "$header_missing_repo" tests/actual.sh
write_check_gate_doc "$header_missing_repo" tests/actual.sh
set +e
header_missing_output="$(check_inventory "$header_missing_repo" 2>&1)"
header_missing_status=$?
set -e
if [[ $header_missing_status -eq 0 || "$header_missing_output" != *"tests/actual.sh"* || "$header_missing_output" != *"non-empty '# Focus:' header"* ]]; then
  echo "missing '# Focus:' header fixture did not fail with expected diagnostic" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$header_missing_output" >&2
  exit 1
fi

header_empty_repo="$TMPDIR/header-empty"
mkdir -p "$header_empty_repo"
make_fixture_repo "$header_empty_repo" tests/actual.sh
write_check_gate_doc "$header_empty_repo" tests/actual.sh
printf '#!/usr/bin/env bash\n# Focus:\n' > "$header_empty_repo/tests/actual.sh"
set +e
header_empty_output="$(check_inventory "$header_empty_repo" 2>&1)"
header_empty_status=$?
set -e
if [[ $header_empty_status -eq 0 || "$header_empty_output" != *"tests/actual.sh"* || "$header_empty_output" != *"non-empty '# Focus:' header"* ]]; then
  echo "empty '# Focus:' header fixture did not fail with expected diagnostic" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$header_empty_output" >&2
  exit 1
fi

check_inventory "$REPO_ROOT"

echo "check-gate inventory: PASS"
