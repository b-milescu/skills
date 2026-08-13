#!/usr/bin/env bash
set -euo pipefail

TEST_NAME=terraform-tofu-invariants
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

SKILL="$REPO_ROOT/terraform-tofu/SKILL.md"
AUTHORING="$REPO_ROOT/terraform-tofu/reference/authoring.md"
TESTING="$REPO_ROOT/terraform-tofu/reference/native-testing.md"
INSTALLER="$REPO_ROOT/install.sh"

for file in "$SKILL" "$AUTHORING" "$TESTING"; do
  assert_path_readable "$file" "terraform-tofu skill file"
done

frontmatter="$(awk 'NR == 1 { if ($0 != "---") exit 2; next } $0 == "---" { exit } { print }' "$SKILL")"
assert_text_contains "$frontmatter" 'name: terraform-tofu' 'skill name'
assert_text_contains "$frontmatter" 'Author or change Terraform/OpenTofu configuration' 'authoring trigger'
assert_text_contains "$frontmatter" 'another skill needs Terraform/OpenTofu implementation' 'skill-to-skill trigger'
assert_text_not_contains "$frontmatter" 'disable-model-invocation: true' 'disabled model invocation'

red_line="$(grep -n '^## 3\. Prove native RED$' "$SKILL" | cut -d: -f1)"
green_line="$(grep -n '^## 4\. Make the smallest GREEN change$' "$SKILL" | cut -d: -f1)"
[[ -n "$red_line" && -n "$green_line" && "$red_line" -lt "$green_line" ]] || fail 'native RED must precede GREEN'

for token in \
  'exactly one of `terraform` or `tofu`' \
  'Missing, conflicting, ambiguous, or constraint-only evidence blocks work.' \
  'unsupported required test feature blocks work' \
  'behavior-level `.tftest.hcl` test first' \
  'run exactly `terraform test` or `tofu test`' \
  'A passing-first test, unrelated error, unexecuted test, parse/setup failure, or external framework is not RED' \
  'Do not silently change the engine' \
  'Invoke `/forge preflight` exactly once' \
  'Use `/forge snapshot` only when issue, change-request, or CI context exists.' \
  'record `forge_mode: local-only`' \
  'The skill never publishes, approves, merges, queues, or performs post-merge actions.' \
  '[authoring rules](reference/authoring.md)' \
  '[native-testing rules](reference/native-testing.md)'; do
  assert_file_contains "$SKILL" "$token"
done

for token in \
  'Set `command = plan` in every safe-workflow run block.' \
  'native mock providers' \
  'Do not use `command = apply` against real infrastructure by default.' \
  'isolated credentials' \
  'isolated local state and backend boundaries' \
  'deterministic cleanup plus observed cleanup evidence' \
  'https://developer.hashicorp.com/terraform/language/tests' \
  'https://opentofu.org/docs/cli/commands/test/'; do
  assert_file_contains "$TESTING" "$token"
done

reject_text "$TESTING" 'default plan-mode|plan-mode default|defaults? to plan' 'wording that implies plan is the native engine default'

for token in \
  'explicit provider source/version constraints' \
  'variables precise types' \
  'Mark secret-bearing variables and outputs `sensitive = true`' \
  '`for_each` with stable, meaningful keys' \
  'Add `depends_on` or `lifecycle` only for an intentional behavior' \
  'Do not add provisioners.' \
  'Do not change backend or state behavior' \
  'https://developer.hashicorp.com/terraform/language/style' \
  'https://opentofu.org/docs/language/syntax/style/'; do
  assert_file_contains "$AUTHORING" "$token"
done

assert_file_contains "$INSTALLER" '[[ -f "$dir/SKILL.md" ]] || continue' 'generic skill discovery'
reject_text "$INSTALLER" 'terraform-tofu' 'installer special case'

printf '%s: PASS\n' "$TEST_NAME"
