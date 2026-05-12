#!/usr/bin/env bash
set -euo pipefail

repo="${1:-OMT-Global/icloud-cli}"
branch="${2:-main}"

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
if protection_json="$(gh api "repos/${repo}/branches/${branch}/protection" 2>/tmp/icloud-cli-branch-protection.err)"; then
  jq '{
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
  }' <<<"$protection_json"
else
  echo "Branch protection is not available or not enabled for ${repo}:${branch}." >&2
  cat /tmp/icloud-cli-branch-protection.err >&2
  exit 2
fi
