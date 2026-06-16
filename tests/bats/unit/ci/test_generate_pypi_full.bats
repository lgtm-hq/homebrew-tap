#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for full PyPI formula generation with pinned resources (winnow).

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

@test "generate-pypi-formula: winnow full formula matches fixture" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	output_file="$TEST_TEMP_DIR/winnow.rb"

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$output_file"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'resource "click" do' "$output_file"
	grep -q 'venv.pip_install other_resources' "$output_file"
	assert_files_equal "$REPO_ROOT/tests/fixtures/expected/winnow-full.rb" "$output_file"
}
