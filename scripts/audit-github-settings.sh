#!/usr/bin/env bash
set -euo pipefail

repo="${1:-OMT-Global/icloud-cli}"
branch="${2:-main}"

url_encode_path_segment() {
  local raw="$1"
  local encoded=""
  local i char
  for ((i = 0; i < ${#raw}; i++)); do
    char="${raw:i:1}"
    case "$char" in
      [a-zA-Z0-9._~-])
        encoded+="$char"
        ;;
      *)
        printf -v encoded '%s%%%02X' "$encoded" "'$char"
        ;;
    esac
  done
  printf '%s' "$encoded"
}

encoded_branch="$(url_encode_path_segment "$branch")"

echo "Repository settings for ${repo}:"
gh repo view "$repo" \
  --json nameWithOwner,visibility,deleteBranchOnMerge,hasIssuesEnabled,hasProjectsEnabled \
  --jq '{
    nameWithOwner,
    visibility,
    deleteBranchOnMerge,
    hasIssuesEnabled,
    hasProjectsEnabled
  }'

echo
echo "Branch protection for ${repo}:${branch}:"
if protection_summary="$(gh api "repos/${repo}/branches/${encoded_branch}/protection" \
  --jq '{
    requiredStatusChecks: .required_status_checks.contexts,
    strictStatusChecks: .required_status_checks.strict,
    requiredApprovingReviewCount: .required_pull_request_reviews.required_approving_review_count,
    requireCodeOwnerReviews: .required_pull_request_reviews.require_code_owner_reviews,
    requireLastPushApproval: .required_pull_request_reviews.require_last_push_approval,
    dismissStaleReviews: .required_pull_request_reviews.dismiss_stale_reviews,
    requiredLinearHistory: .required_linear_history.enabled,
    requiredConversationResolution: .required_conversation_resolution.enabled,
    enforceAdmins: .enforce_admins.enabled,
    allowForcePushes: .allow_force_pushes.enabled,
    allowDeletions: .allow_deletions.enabled
  }' \
  2>/tmp/icloud-cli-branch-protection.err)"; then
  printf '%s\n' "$protection_summary"
else
  echo "Branch protection is not available or not enabled for ${repo}:${branch}." >&2
  cat /tmp/icloud-cli-branch-protection.err >&2
  exit 2
fi
