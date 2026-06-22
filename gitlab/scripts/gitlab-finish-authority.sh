#!/usr/bin/env bash
# Deterministic, pure-local finish authority gate.
#
# Decides role authority finish action: extracts role × merge-authority
# × action case logic gitlab/scripts/gitlab-finish-mr.sh (the inline
# finish authority switch) so authority enforced deterministically
# in prose. Makes NO network call: only validates ids compares strings
# handed. Transport-layer confirm/sha guards enforce intent
# head-binding; context firewall enforces review independence.
#
# Canonical authority seam: gitlab/reference/authority-verification.md
# Finish decision table: gitlab/reference/authority-matrix.md
# Identity lifecycle: gitlab/reference/identity-and-authentication.md
#
# Exit 0 only if:
# (a) role × merge-authority × action combo is allowed by matrix, AND
# (b) caller_user_id / mr_author_id present audit token-stability checks.
# Otherwise non-zero reason= in:
# invalid_user_id (empty/missing caller or author id)
# authority_source_mismatch (declared authority source != expected, checked)
# authority (role × authority or finish-owner routing does not permit action)

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-finish-authority.sh --caller-role <role> --caller-user-id <id> \
  --mr-author-id <id> --merge-authority <authority> --action <action> \
  [--finish-owner <caller|parent>] [--authority-source <s>] \
  [--expected-authority-source <s>]

Caller roles: builder | reviewer | authorized-parent | human
Merge authorities: approval-only | reviewer may merge | queue auto-merge | human release
Actions: handoff | approve | merge | queue-auto-merge
Finish owners: caller (default) | parent

Exit codes:
  0  action permitted
  4  reason=authority role x authority does not permit action
  7  reason=invalid_user_id empty/missing caller or author id
  8  reason=authority_source_mismatch declared source != expected source
  64 usage / argument error
USAGE
}

caller_role=""
caller_user_id=""
mr_author_id=""
merge_authority=""
action=""
authority_source=""
expected_authority_source=""
finish_owner="caller"
caller_user_id_set=false
mr_author_id_set=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --caller-role) caller_role="${2:-}"; shift 2 ;;
    --caller-user-id) caller_user_id="${2:-}"; caller_user_id_set=true; shift 2 ;;
    --mr-author-id) mr_author_id="${2:-}"; mr_author_id_set=true; shift 2 ;;
    --merge-authority) merge_authority="${2:-}"; shift 2 ;;
    --action) action="${2:-}"; shift 2 ;;
    --finish-owner) finish_owner="${2:-}"; shift 2 ;;
    --authority-source) authority_source="${2:-}"; shift 2 ;;
    --expected-authority-source) expected_authority_source="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "AUTHORITY_GATE result=blocked reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

block() {
  echo "AUTHORITY_GATE result=blocked reason=$2 caller_role=$caller_role merge_authority=$merge_authority action=$action finish_owner=$finish_owner" >&2
  exit "$1"
}

[[ -n "$caller_role" ]] || { echo "AUTHORITY_GATE result=blocked reason=missing_caller_role" >&2; exit 64; }
[[ -n "$merge_authority" ]] || { echo "AUTHORITY_GATE result=blocked reason=missing_merge_authority" >&2; exit 64; }
[[ -n "$action" ]] || { echo "AUTHORITY_GATE result=blocked reason=missing_action" >&2; exit 64; }
"$caller_user_id_set" || { echo "AUTHORITY_GATE result=blocked reason=missing_caller_user_id" >&2; exit 64; }
"$mr_author_id_set" || { echo "AUTHORITY_GATE result=blocked reason=missing_mr_author_id" >&2; exit 64; }

case "$caller_role" in
  builder|reviewer|authorized-parent|human) ;;
  *) echo "AUTHORITY_GATE result=blocked reason=unknown_caller_role caller=$caller_role" >&2; exit 64 ;;
esac
case "$merge_authority" in
  approval-only|reviewer\ may\ merge|queue\ auto-merge|human\ release) ;;
  *) echo "AUTHORITY_GATE result=blocked reason=unknown_merge_authority authority=$merge_authority" >&2; exit 64 ;;
esac
case "$action" in
  handoff|approve|merge|queue-auto-merge) ;;
  *) echo "AUTHORITY_GATE result=blocked reason=unknown_action action=$action" >&2; exit 64 ;;
esac
case "$finish_owner" in
  caller|parent) ;;
  *) echo "AUTHORITY_GATE result=blocked reason=unknown_finish_owner finish_owner=$finish_owner" >&2; exit 64 ;;
esac

[[ -n "$caller_user_id" && -n "$mr_author_id" ]] || block 7 invalid_user_id

if [[ -n "$expected_authority_source" && "$authority_source" != "$expected_authority_source" ]]; then
  block 8 authority_source_mismatch
fi

if [[ "$action" == "handoff" ]]; then
  exit 0
fi

if [[ "$caller_role" == "builder" ]]; then
  block 4 authority
fi

# Parent-managed dev-flow: reviewer reports verdict/evidence and hands off;
# parent/authorized-parent/human finish paths still use the normal matrix.
if [[ "$finish_owner" == "parent" && "$caller_role" == "reviewer" ]]; then
  block 4 authority
fi

case "$merge_authority:$action" in
  approval-only:approve) exit 0 ;;
  reviewer\ may\ merge:merge) exit 0 ;;
  reviewer\ may\ merge:approve) exit 0 ;;
  queue\ auto-merge:queue-auto-merge) exit 0 ;;
  *) block 4 authority ;;
esac
