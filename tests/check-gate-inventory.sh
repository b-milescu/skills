#!/usr/bin/env bash
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
    printf '| Script | Focus |\n'
    printf '| --- | --- |\n'
    local script
    for script in "$@"; do
      printf '| `%s` | Fixture focus. |\n' "$script"
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

list_tracked_test_scripts() {
  local repo="$1"
  git -C "$repo" ls-files 'tests/*.sh' | awk '/^tests\/[^\/]+\.sh$/ { print }' | sort
}

check_inventory() {
  local repo="$1"
  local actual_file="$TMPDIR/actual.$(basename "$repo").txt"
  local inventory_file="$TMPDIR/inventory.$(basename "$repo").txt"
  local missing_file="$TMPDIR/missing.$(basename "$repo").txt"
  local extra_file="$TMPDIR/extra.$(basename "$repo").txt"

  list_tracked_test_scripts "$repo" > "$actual_file"
  extract_inventory_scripts "$repo" > "$inventory_file"

  comm -23 "$actual_file" "$inventory_file" > "$missing_file"
  comm -13 "$actual_file" "$inventory_file" > "$extra_file"

  if [[ -s "$missing_file" || -s "$extra_file" ]]; then
    echo "Check Gate shipped shell regression inventory is out of sync with top-level tracked tests/*.sh files." >&2
    if [[ -s "$missing_file" ]]; then
      echo "Missing from docs/agents/check-gate.md inventory:" >&2
      sed 's/^/  - /' "$missing_file" >&2
    fi
    if [[ -s "$extra_file" ]]; then
      echo "Inventory entries with no tracked tests/*.sh file:" >&2
      sed 's/^/  - /' "$extra_file" >&2
    fi
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

check_inventory "$REPO_ROOT"

echo "check-gate inventory: PASS"
