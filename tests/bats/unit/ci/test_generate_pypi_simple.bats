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
	simple_config="$TEST_TEMP_DIR/winnow-simple.yml"

	cat >"$simple_config" <<'EOF'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    python-version: "3.13"
    test-command: "winnow --version"
EOF

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$simple_config" \
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

@test "read_formula_config: winnow enables generate-resources" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--json

	[ "$status" -eq 0 ]
	run python3 -c "import json, sys; data=json.loads(sys.argv[1]); sys.exit(0 if data.get('generate-resources') is True else 1)" "$output"
	[ "$status" -eq 0 ]
}
