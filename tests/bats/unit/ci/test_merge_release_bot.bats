#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for merge-release-bot-pr.sh branch/title/author checks.

load "../../../helpers/common"
load "../../../helpers/mocks"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	mock_gh "$TEST_TEMP_DIR/mock-bin"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
	export MOCK_PR_NUMBER="42"
}

teardown() {
	teardown_temp_dir
}

run_merge_bot() {
	local branch="$1"
	export WORKFLOW_RUN_HEAD_BRANCH="$branch"
	bash "$REPO_ROOT/scripts/ci/merge-release-bot-pr.sh"
}

@test "merge-release-bot-pr: merges winnow-style homebrew branch" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1"

	run run_merge_bot "homebrew/winnow-0.0.1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Enabling auto-merge for PR #42"* ]]
}

@test "merge-release-bot-pr: still merges lintro-style branch" {
	export MOCK_AUTHOR="homebrew-tap-release-bot[bot]"
	export MOCK_TITLE="chore(homebrew): update lintro to 0.64.4"

	run run_merge_bot "homebrew/lintro-0.64.4"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Enabling auto-merge for PR #42"* ]]
}

@test "merge-release-bot-pr: merges dot-less integer version branch" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 1"

	run run_merge_bot "homebrew/winnow-1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Enabling auto-merge for PR #42"* ]]
}

@test "merge-release-bot-pr: skips unrelated branch" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1"

	run run_merge_bot "feature/unrelated-branch"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipping merge"* ]]
}

@test "merge-release-bot-pr: skips invalid homebrew branch format" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1"

	run run_merge_bot "homebrew/winnow"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipping merge"* ]]
}

@test "merge-release-bot-pr: skips unexpected title" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="feat: add something else"

	run run_merge_bot "homebrew/winnow-0.0.1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"unexpected PR title"* ]]
}

@test "merge-release-bot-pr: skips untrusted author" {
	export MOCK_AUTHOR="some-user"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1"

	run run_merge_bot "homebrew/winnow-0.0.1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"expected release bot"* ]]
}

@test "merge-release-bot-pr: skips branch with trailing malicious content" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1"

	run run_merge_bot "homebrew/winnow-0.0.1; rm -rf /"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipping merge"* ]]
}

@test "merge-release-bot-pr: skips title with trailing malicious content" {
	export MOCK_AUTHOR="github-actions[bot]"
	export MOCK_TITLE="chore(homebrew): update winnow to 0.0.1; malicious"

	run run_merge_bot "homebrew/winnow-0.0.1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"unexpected PR title"* ]]
}
