#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GATE="$REPO_ROOT/gitlab-local/scripts/gitlab-finish-authority.sh"
MATRIX="$REPO_ROOT/gitlab-local/reference/authority-matrix.md"

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_gate() {
  set +e
  CAPTURE_OUTPUT="$("$GATE" "$@" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_contains() {
  [[ "$CAPTURE_OUTPUT" == *"$1"* ]] || fail "expected output to contain '$1'; got: $CAPTURE_OUTPUT"
}

# --- builder is always blocked from non-handoff actions ---
run_gate --caller-role builder --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "reviewer may merge" --action merge
assert_status 4
assert_contains "reason=authority"

# same GitLab identity does not relax the builder boundary
run_gate --caller-role builder --caller-user-id 7 --mr-author-id 7 \
  --merge-authority "reviewer may merge" --action merge
assert_status 4
assert_contains "reason=authority"

# builder handoff is allowed
run_gate --caller-role builder --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "reviewer may merge" --action handoff
assert_status 0

# --- same GitLab identity does not block a clean-context reviewer ---
run_gate --caller-role reviewer --caller-user-id 5 --mr-author-id 5 \
  --merge-authority "reviewer may merge" --action merge
assert_status 0

run_gate --caller-role reviewer --caller-user-id 5 --mr-author-id 5 \
  --merge-authority "approval-only" --action approve
assert_status 0

# handoff is allowed even when caller == author (stopping is always permitted)
run_gate --caller-role reviewer --caller-user-id 3 --mr-author-id 3 \
  --merge-authority "approval-only" --action handoff
assert_status 0

# --- invalid_user_id: empty/missing ids ---
run_gate --caller-role reviewer --caller-user-id "" --mr-author-id 9 \
  --merge-authority "reviewer may merge" --action merge
assert_status 7
assert_contains "reason=invalid_user_id"

run_gate --caller-role reviewer --caller-user-id 7 --mr-author-id "" \
  --merge-authority "reviewer may merge" --action merge
assert_status 7
assert_contains "reason=invalid_user_id"

# --- reviewer may merge -> merge allowed ---
run_gate --caller-role reviewer --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "reviewer may merge" --action merge
assert_status 0

# --- queue auto-merge -> queue-auto-merge allowed ---
run_gate --caller-role authorized-parent --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "queue auto-merge" --action queue-auto-merge
assert_status 0

# --- approval-only -> approve allowed, merge blocked ---
run_gate --caller-role reviewer --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "approval-only" --action approve
assert_status 0

run_gate --caller-role reviewer --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "approval-only" --action merge
assert_status 4
assert_contains "reason=authority"

# --- human release -> handoff only ---
run_gate --caller-role human --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "human release" --action handoff
assert_status 0

run_gate --caller-role human --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "human release" --action merge
assert_status 4
assert_contains "reason=authority"

# --- queue auto-merge does not grant direct merge ---
run_gate --caller-role reviewer --caller-user-id 7 --mr-author-id 9 \
  --merge-authority "queue auto-merge" --action merge
assert_status 4
assert_contains "reason=authority"

# --- no network call: the script must not reference glab/curl/wget/git remote ---
if grep -Eq '(^|[^a-zA-Z_])(glab|curl|wget)([^a-zA-Z_]|$)' "$GATE"; then
  fail "gate script must make no network call (found glab/curl/wget reference)"
fi

# === Matrix-match test: parse authority-matrix.md and assert the gate agrees ===
# Build the set of allowed actions per (role, authority) from the decision table,
# then exhaustively probe the gate for every role × authority × action.
roles=(builder reviewer authorized-parent human)
authorities=("approval-only" "reviewer may merge" "queue auto-merge" "human release")
actions=(handoff approve merge queue-auto-merge)

# Map an authority column header to its table column index (1-based among data cols).
authority_col_index() {
  case "$1" in
    "approval-only") echo 1 ;;
    "reviewer may merge") echo 2 ;;
    "queue auto-merge") echo 3 ;;
    "human release") echo 4 ;;
    *) echo 0 ;;
  esac
}

# Extract the cell text for a given role row and authority column from the matrix.
matrix_cell() {
  local role="$1" authority="$2"
  local col
  col="$(authority_col_index "$authority")"
  awk -v role="\`$role\`" -v col="$col" '
    /^\| `(builder|reviewer|authorized-parent|human)` \|/ {
      # split on | and find the row whose first data cell matches the role
      n = split($0, parts, "|")
      # parts[1] is empty (leading |); parts[2] is the role cell
      gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
      if (parts[2] == role) {
        # data columns start at parts[3]
        cell = parts[2 + col]
        gsub(/^[ \t]+|[ \t]+$/, "", cell)
        print cell
        exit
      }
    }
  ' "$MATRIX"
}

cell_allows() {
  # cell_allows "<cell text>" "<action>" -> 0 if allowed, 1 otherwise
  local cell="$1" action="$2"
  local item
  local IFS=','
  for item in $cell; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ "$item" == "$action" ]] && return 0
  done
  return 1
}

matrix_checks=0
for role in "${roles[@]}"; do
  for authority in "${authorities[@]}"; do
    cell="$(matrix_cell "$role" "$authority")"
    [[ -n "$cell" ]] || fail "matrix has no cell for role=$role authority=$authority"
    for action in "${actions[@]}"; do
      # Use valid ids; same GitLab identity is permitted for gate-eligible roles.
      run_gate --caller-role "$role" --caller-user-id 100 --mr-author-id 200 \
        --merge-authority "$authority" --action "$action"
      if cell_allows "$cell" "$action"; then
        [[ "$CAPTURE_STATUS" -eq 0 ]] || \
          fail "matrix allows $role/$authority/$action but gate blocked it (status=$CAPTURE_STATUS, out=$CAPTURE_OUTPUT)"
      else
        [[ "$CAPTURE_STATUS" -eq 4 ]] || \
          fail "matrix forbids $role/$authority/$action but gate did not block with authority (status=$CAPTURE_STATUS, out=$CAPTURE_OUTPUT)"
        assert_contains "reason=authority"
      fi
      matrix_checks=$((matrix_checks + 1))
    done
  done
done

[[ "$matrix_checks" -eq 64 ]] || fail "expected 64 matrix probes, ran $matrix_checks"

echo "gitlab-finish-authority: PASS ($matrix_checks matrix probes)"
