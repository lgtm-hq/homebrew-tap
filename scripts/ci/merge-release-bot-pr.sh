#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Squash-merge trusted release-bot Homebrew tap PRs after CI succeeds.

set -euo pipefail

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
HEAD_BRANCH="${WORKFLOW_RUN_HEAD_BRANCH:?WORKFLOW_RUN_HEAD_BRANCH is required}"

if [[ ! "$HEAD_BRANCH" =~ ^homebrew/lintro ]]; then
	echo "Skipping merge: branch '${HEAD_BRANCH}' is not a release-bot tap branch."
	exit 0
fi

PR_NUMBER="$(
	gh pr list \
		--repo "$REPO" \
		--head "$HEAD_BRANCH" \
		--state open \
		--json number \
		--jq '.[0].number // empty'
)"

if [[ -z "$PR_NUMBER" ]]; then
	echo "No open PR for head '${HEAD_BRANCH}'."
	exit 0
fi

AUTHOR_LOGIN="$(
	gh pr view "$PR_NUMBER" \
		--repo "$REPO" \
		--json author \
		--jq '.author.login'
)"

if [[ "$AUTHOR_LOGIN" != "homebrew-tap-release-bot" && "$AUTHOR_LOGIN" != "homebrew-tap-release-bot[bot]" ]]; then
	echo "Skipping merge: PR #${PR_NUMBER} author is '${AUTHOR_LOGIN}', expected release bot."
	exit 0
fi

TITLE="$(
	gh pr view "$PR_NUMBER" \
		--repo "$REPO" \
		--json title \
		--jq -r '.title'
)"

if [[ ! "$TITLE" =~ ^chore\(homebrew\):\ update\ lintro\ to\  ]]; then
	echo "Skipping merge: unexpected PR title: ${TITLE}"
	exit 0
fi

echo "Merging PR #${PR_NUMBER} (squash, delete branch)."
gh pr merge "$PR_NUMBER" --repo "$REPO" --squash --delete-branch
