#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/docs" "$TMPDIR/images"
cat > "$TMPDIR/docs/index.md" <<'MD'
# Main Doc

See [details](details.md#setup-flow), [local heading](#main-doc), and ![logo](../images/logo.png).

Allowed external: [GitLab](https://gitlab.example.com/agents/skills/-/issues/52).
Angle local: [details angle](<details.md#setup-flow>).
Angle external: [GitLab angle](<https://gitlab.example.com/agents/skills/-/issues/52>).
Malformed nested angle: [nested](<<details.md#setup-flow>>).
Placeholder destination: [skill root]({skill-root}/README.md).
Blocked external: [example](https://example.com/outside-policy).
Broken file: [missing](missing.md).
Broken anchor: [bad anchor](details.md#missing-heading).
Allowed skill URI: [shared resource](skill://start-build/docs/decoupling-contract.md).
MD

cat > "$TMPDIR/docs/details.md" <<'MD'
# Setup Flow

Content.
MD

: > "$TMPDIR/images/logo.png"

set +e
output="$(node "$REPO_ROOT/scripts/check-md-links.mjs" "$TMPDIR/docs/index.md" 2>&1)"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "expected link checker to fail for broken fixture" >&2
  exit 1
fi

for expected in \
  "$TMPDIR/docs/index.md:10: external URL host \"example.com\" is not allowlisted" \
  "$TMPDIR/docs/index.md:11: target file does not exist: missing.md" \
  "$TMPDIR/docs/index.md:12: anchor \"missing-heading\" not found in details.md"; do
  if [[ "$output" != *"$expected"* ]]; then
    echo "missing expected diagnostic: $expected" >&2
    echo "--- output ---" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
done

if [[ "$output" == *"logo.png"* || "$output" == *"setup-flow"* || "$output" == *"main-doc"* || "$output" == *"<details.md"* || "$output" == *"<https://gitlab.example.com"* || "$output" == *"{skill-root}/README.md"* || "$output" == *"skill://start-build/docs/decoupling-contract.md"* ]]; then
  echo "valid file/image/anchor was reported as broken" >&2
  echo "--- output ---" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

echo "md-links regression: PASS"
