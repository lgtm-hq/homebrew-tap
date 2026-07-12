#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for supersede-formula-prs.sh stale bump PR cleanup.

load "../../../helpers/common"
load "../../../helpers/mocks"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	SCRIPT="$REPO_ROOT/scripts/ci/supersede-formula-prs.sh"
	mock_gh_recording "$TEST_TEMP_DIR/mock-bin"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
	export GH_TOKEN="test-token"
}

teardown() {
	teardown_temp_dir
}

@test "supersede: closes older bump PRs with comment and branch delete" {
	export MOCK_OPEN_PRS='[
		{"number": 134, "headRefName": "homebrew/lintro-0.77.2"},
		{"number": 120, "headRefName": "homebrew/lintro-0.76.0"},
		{"number": 119, "headRefName": "homebrew/lintro-0.76.1-rc.1"},
		{"number": 118, "headRefName": "homebrew/lintro-0.75.1"}
	]'

	run bash "$SCRIPT" --product lintro --current-pr 134

	[ "$status" -eq 0 ]
	grep -q \
		"pr close 120 --repo lgtm-hq/homebrew-tap --comment Superseded by #134. --delete-branch" \
		"$MOCK_GH_LOG"
	grep -q \
		"pr close 119 --repo lgtm-hq/homebrew-tap --comment Superseded by #134. --delete-branch" \
		"$MOCK_GH_LOG"
	grep -q \
		"pr close 118 --repo lgtm-hq/homebrew-tap --comment Superseded by #134. --delete-branch" \
		"$MOCK_GH_LOG"
	! grep -q "pr close 134" "$MOCK_GH_LOG"
}

@test "supersede: leaves unrelated and other-product PRs open" {
	export MOCK_OPEN_PRS='[
		{"number": 134, "headRefName": "homebrew/lintro-0.77.2"},
		{"number": 99, "headRefName": "feature/unrelated"},
		{"number": 98, "headRefName": "homebrew/winnow-0.0.2"},
		{"number": 97, "headRefName": "homebrew/lintro-full-0.1.0"}
	]'

	run bash "$SCRIPT" --product lintro --current-pr 134

	[ "$status" -eq 0 ]
	! grep -q "pr close" "$MOCK_GH_LOG"
}

@test "supersede: no-op when only the current PR is open" {
	export MOCK_OPEN_PRS='[
		{"number": 134, "headRefName": "homebrew/lintro-0.77.2"}
	]'

	run bash "$SCRIPT" --product lintro --current-pr 134

	[ "$status" -eq 0 ]
	! grep -q "pr close" "$MOCK_GH_LOG"
	[[ "$output" == *"Superseded PR sweep complete"* ]]
}

@test "supersede: rejects non-numeric current PR" {
	run bash "$SCRIPT" --product lintro --current-pr "abc"

	[ "$status" -eq 1 ]
	[[ "$output" == *"--current-pr must be a PR number"* ]]
}

@test "supersede: requires product and current PR" {
	run bash "$SCRIPT" --product lintro

	[ "$status" -eq 1 ]
	[[ "$output" == *"Missing required arguments"* ]]
}
