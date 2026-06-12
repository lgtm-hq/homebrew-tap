#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for parse-dispatch-payload.sh validation.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output"
	export GITHUB_OUTPUT
}

teardown() {
	teardown_temp_dir
}

@test "parse-dispatch-payload: writes validated outputs" {
	export CLIENT_PAYLOAD='{"formula":"winnow","version":"0.1.0","pypi-package":"winnow-cli","binary-assets":{}}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=winnow$' "$GITHUB_OUTPUT"
	grep -q '^version=0.1.0$' "$GITHUB_OUTPUT"
	grep -q '^pypi-package=winnow-cli$' "$GITHUB_OUTPUT"
	grep -q '^binary-assets<<EOF$' "$GITHUB_OUTPUT"
}

@test "parse-dispatch-payload: rejects invalid formula identifier" {
	export CLIENT_PAYLOAD='{"formula":"../etc/passwd","version":"1.0.0"}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid formula identifier"* ]]
}

@test "parse-dispatch-payload: rejects invalid version" {
	export CLIENT_PAYLOAD='{"formula":"winnow","version":"v1.0.0"}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid version"* ]]
}
