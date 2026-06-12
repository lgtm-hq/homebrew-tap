#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for binary formula generation.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
}

teardown() {
	teardown_temp_dir
}

@test "generate-binary-formula: lintro binary structure and SHAs" {
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets='{"arm64-sha":"a4c1663e5908757746676c9a48bdc35a4d0ef4dbaa3bd6a96dd3a29c0a0d4c10","x86-sha":"fdab37737c071fb07543c5fd2f99a36bb3031524ba7a25b6bd63aa333bed12f5"}'

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version 0.64.4 \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -eq 0 ]
	grep -q 'class Lintro < Formula' "$output_file"
	grep -q 'version "0.64.4"' "$output_file"
	grep -q 'a4c1663e5908757746676c9a48bdc35a4d0ef4dbaa3bd6a96dd3a29c0a0d4c10' "$output_file"
	grep -q 'fdab37737c071fb07543c5fd2f99a36bb3031524ba7a25b6bd63aa333bed12f5' "$output_file"
	grep -q 'lintro-macos-arm64' "$output_file"
}

@test "generate-binary-formula: parity with committed lintro.rb" {
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets='{"arm64-sha":"a4c1663e5908757746676c9a48bdc35a4d0ef4dbaa3bd6a96dd3a29c0a0d4c10","x86-sha":"fdab37737c071fb07543c5fd2f99a36bb3031524ba7a25b6bd63aa333bed12f5"}'

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version 0.64.4 \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -eq 0 ]
	assert_files_equal "$REPO_ROOT/Formula/lintro.rb" "$output_file"
}
