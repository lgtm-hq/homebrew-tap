#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for simple PyPI formula generation (winnow).

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

@test "generate-pypi-formula: winnow simple formula matches fixture" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	output_file="$TEST_TEMP_DIR/winnow.rb"

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$output_file"

	[ "$status" -eq 0 ]
	assert_files_equal "$REPO_ROOT/tests/fixtures/expected/winnow.rb" "$output_file"
}

@test "read_formula_config: lists winnow formula keys" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/winnow.yml" \
		--list-formulas

	[ "$status" -eq 0 ]
	[[ "$output" == "winnow" ]]
}
