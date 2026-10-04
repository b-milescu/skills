#!/usr/bin/env bash
# Focus: `scripts/check.sh` runs every `tests/*.mjs` (`bun <file>`) and every
# `tests/*.sh` in its own exit-gated process, keeps going after one fails (a
# throw or a late async throw included) and after one calls `process.exit(0)`,
# ends with the failing-set list and a non-zero exit, and still prints
# `check: PASS` only on a green run. An empty `tests/*.mjs` match runs nothing
# instead of falling back to Bun's repo-wide *.test.* discovery.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Stub the pre-loop `bun run check:*` steps so only the test loop is under test;
# every other bun invocation (`bun <file>`) reaches the real binary.
REAL_BUN="$(command -v bun)"
export REAL_BUN
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == run ]] && exit 0\nexec "$REAL_BUN" "$@"\n' > "$WORK/bin/bun"
chmod +x "$WORK/bin/bun"

make_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts" "$repo/agents" "$repo/tests"
  cp "$REPO_ROOT/scripts/check.sh" "$repo/scripts/check.sh"
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
printf 'process.exit(0);\n' > "$green/tests/a-exit0.mjs"
run_gate "$green" "$WORK/green.out" || fail "green run exited non-zero: $(cat "$WORK/green.out")"
assert_file_contains "$WORK/green.out" "check: PASS" "green PASS line"
assert_path_readable "$green/ran-z-pass-mjs" "tests/*.mjs script after a file that called process.exit(0)"

# Empty glob: no top-level tests/*.mjs plus a decoy matching Bun's default
# test patterns. Nothing runs; a bare `bun test` would discover the decoy.
empty="$WORK/empty"
make_repo "$empty"
rm "$empty/tests/z-pass.mjs"
printf 'import { writeFileSync } from "node:fs";\nwriteFileSync("ran-decoy", "");\n' > "$empty/decoy.test.mjs"
run_gate "$empty" "$WORK/empty.out" || fail "empty-glob run exited non-zero: $(cat "$WORK/empty.out")"
assert_path_absent "$empty/ran-decoy" "decoy run: empty tests/*.mjs glob fell back to Bun default discovery"

red="$WORK/red"
make_repo "$red"
printf 'exit 1\n' > "$red/tests/a-fail.sh"
printf 'exit 3\n' > "$red/tests/m-fail.sh"
printf 'throw new Error("planted");\n' > "$red/tests/b-fail.mjs"
printf 'setTimeout(() => { throw new Error("late"); }, 50);\n' > "$red/tests/late-fail.mjs"
if run_gate "$red" "$WORK/red.out"; then
  fail "red run exited 0: $(cat "$WORK/red.out")"
fi
assert_path_readable "$red/ran-z-pass" "script after a failing script to still run"
assert_file_contains "$WORK/red.out" "check: FAIL" "failing-set summary"
summary="$(sed -n '/^check: FAIL/,$p' "$WORK/red.out")"
assert_contains "$summary" "tests/a-fail.sh" "first failing script in summary"
assert_contains "$summary" "tests/m-fail.sh" "second failing script in summary"
assert_contains "$summary" "tests/b-fail.mjs" "throwing script in summary"
assert_contains "$summary" "tests/late-fail.mjs" "late async throw in summary"
assert_not_contains "$summary" "tests/z-pass.sh" "passing script in summary"
assert_not_contains "$summary" "tests/z-pass.mjs" "passing .mjs file in summary"
assert_file_not_contains "$WORK/red.out" "check: PASS" "PASS line on a red run"

echo "check-gate-runner: PASS"
