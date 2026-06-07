#!/usr/bin/env bash
# Deterministic, pure-local finish authority gate.
#
# Decides role authority for a finish action: extracts the role × merge-authority
# × action case logic from gitlab-local/scripts/gitlab-finish-mr.sh (the inline
# finish authority switch) so authority is enforced deterministically rather than
# in prose. Makes NO network call: it only validates ids and compares the strings
# it is handed. Transport-layer confirm/sha guards enforce intent and
# head-binding; the context firewall enforces review independence.
#
# Canonical authority seam: gitlab-local/reference/authority-verification.md
# Finish decision table:     gitlab-local/reference/authority-matrix.md
# Identity lifecycle:        gitlab-local/reference/identity-and-authentication.md
#
# Exit 0 only if:
#   (a) the role × merge-authority × action combo is allowed by the matrix, AND
#   (b) caller_user_id / mr_author_id are present for audit and token-stability checks.
# Otherwise non-zero with reason= in:
#   invalid_user_id          (empty/missing caller or author id)
#   authority_source_mismatch (declared authority source != expected, when checked)
#   authority                (role × authority does not permit the action)

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-finish-authority.sh --caller-role <role> --caller-user-id <id> \
  --mr-author-id <id> --merge-authority <authority> --action <action> \
  [--authority-source <s>] [--expected-authority-source <s>]

Caller roles:  builder | reviewer | authorized-parent | human
Merge authorities: approval-only | reviewer may merge | queue auto-merge | human release
Actions:       handoff | approve | merge | queue-auto-merge

Exit codes:
  0   action permitted
  4   reason=authority                role x authority does not permit the action
  7   reason=invalid_user_id          empty/missing caller or author id
  8   reason=authority_source_mismatch declared source != expected source
  64  usage / argument error
USAGE
}

caller_role=""
caller_user_id=""
mr_author_id=""
merge_authority=""
action=""
authority_source=""
expected_authority_source=""
# Sentinels distinguish "flag omitted" from "flag passed empty" for the id flags.
caller_user_id_set=false
mr_author_id_set=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --caller-role) caller_role="${2:-}"; shift 2 ;;
    --caller-user-id) caller_user_id="${2:-}"; caller_user_id_set=true; shift 2 ;;
    --mr-author-id) mr_author_id="${2:-}"; mr_author_id_set=true; shift 2 ;;
    --merge-authority) merge_authority="${2:-}"; shift 2 ;;
    --action) action="${2:-}"; shift 2 ;;
    --authority-source) authority_source="${2:-}"; shift 2 ;;
    --expected-authority-source) expected_authority_source="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "AUTHORITY_GATE result=blocked reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
  esac
done

block() {
  # block <exit_code> <reason>
  echo "AUTHORITY_GATE result=blocked reason=$2 caller_role=$caller_role merge_authority=$merge_authority action=$action" >&2
  exit "$1"
}

# --- argument validation (usage errors, distinct from authority decisions) ---
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

# --- decision order (fail-closed) ---
# 1. invalid_user_id: ids are required and must be non-empty for every decision.
[[ -n "$caller_user_id" && -n "$mr_author_id" ]] || block 7 invalid_user_id

# 2. authority_source_mismatch: when an expected source is declared, the caller's
#    declared source must match it. Only checked when both are provided.
if [[ -n "$expected_authority_source" && "$authority_source" != "$expected_authority_source" ]]; then
  block 8 authority_source_mismatch
fi

# 3. authority: role x merge-authority x action matrix. Mirrors the inline switch
#    in gitlab-finish-mr.sh and gitlab-local/reference/authority-matrix.md.
#    handoff is always allowed (stopping is never blocked by authority).
if [[ "$action" == "handoff" ]]; then
  exit 0
fi

# builder never approves/merges/queues, regardless of merge authority.
if [[ "$caller_role" == "builder" ]]; then
  block 4 authority
fi

case "$merge_authority:$action" in
  approval-only:approve) exit 0 ;;
  reviewer\ may\ merge:merge) exit 0 ;;
  reviewer\ may\ merge:approve) exit 0 ;;
  queue\ auto-merge:queue-auto-merge) exit 0 ;;
  *) block 4 authority ;;
esac
