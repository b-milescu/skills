#!/usr/bin/env bash
# Focus: `scripts/check.sh` runs `node --test 'tests/*.mjs'` and every
# `tests/*.sh`, keeps going after one fails, ends with the failing-set list and
# a non-zero exit, and still prints `check: PASS` only on a green run (issues
# #493, #498).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Stub every pre-loop step so only the test-script loop is under test.
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/npm"
chmod +x "$WORK/bin/npm"

make_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts" "$repo/agents" "$repo/tests"
  cp "$REPO_ROOT/scripts/check.sh" "$repo/scripts/check.sh"
  : > "$repo/install.sh"
  : > "$repo/agents/check.sh"
  printf 'touch ran-z-pass\n' > "$repo/tests/z-pass.sh"
  printf 'import { writeFileSync } from "node:fs";\nwriteFileSync("ran-z-pass-mjs", "");\n' > "$repo/tests/z-pass.mjs"
}

run_gate() {
  local repo="$1" output="$2"
  set +e
  PATH="$WORK/bin:$PATH" bash "$repo/scripts/check.sh" > "$output" 2>&1
  local status=$?
  set -e
  return "$status"
}

green="$WORK/green"
make_repo "$green"
run_gate "$green" "$WORK/green.out" || fail "green run exited non-zero: $(cat "$WORK/green.out")"
assert_file_contains "$WORK/green.out" "check: PASS" "green PASS line"
assert_path_readable "$green/ran-z-pass-mjs" "tests/*.mjs file to run under node --test"

red="$WORK/red"
make_repo "$red"
printf 'exit 1\n' > "$red/tests/a-fail.sh"
printf 'exit 3\n' > "$red/tests/m-fail.sh"
printf 'throw new Error("planted");\n' > "$red/tests/b-fail.mjs"
if run_gate "$red" "$WORK/red.out"; then
  fail "red run exited 0: $(cat "$WORK/red.out")"
fi
assert_path_readable "$red/ran-z-pass" "script after a failing script to still run"
assert_file_contains "$WORK/red.out" "check: FAIL" "failing-set summary"
summary="$(sed -n '/^check: FAIL/,$p' "$WORK/red.out")"
assert_contains "$summary" "tests/a-fail.sh" "first failing script in summary"
assert_contains "$summary" "tests/m-fail.sh" "second failing script in summary"
assert_contains "$summary" "tests/*.mjs" "failing node --test step in summary"
assert_not_contains "$summary" "tests/z-pass.sh" "passing script in summary"
assert_file_not_contains "$WORK/red.out" "check: PASS" "PASS line on a red run"

echo "check-gate-runner: PASS"
