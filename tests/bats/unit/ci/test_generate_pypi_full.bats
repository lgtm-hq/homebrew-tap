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
	full_config="$TEST_TEMP_DIR/winnow-full.yml"

	cat >"$full_config" <<'EOF'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "winnow --version"
EOF

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$full_config" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$output_file"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'resource "click" do' "$output_file"
	grep -q 'venv.pip_install resources' "$output_file"
	! grep -q 'pydantic_core' "$output_file"
	! grep -q 'def caveats' "$output_file"
	assert_files_equal "$REPO_ROOT/tests/fixtures/expected/winnow-full.rb" "$output_file"
}

@test "read_formula_config: winnow enables pydantic_core wheel-only package" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--json

	[ "$status" -eq 0 ]
	run python3 -c "import json, sys; data=json.loads(sys.argv[1]); wheel=data.get('wheel-only-packages', {}); sys.exit(0 if wheel.get('pydantic_core', {}).get('type') == 'platform' else 1)" "$output"
	[ "$status" -eq 0 ]
}
