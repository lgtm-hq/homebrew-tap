#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for detect-formula-changes.sh path decision logic.

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

@test "detect-formula-changes: formula file requires validation" {
	export CHANGED_FILES=$'Formula/lintro.rb\nREADME.md'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: script change requires validation" {
	export CHANGED_FILES='scripts/ci/generate-binary-formula.sh'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: config change requires validation" {
	export CHANGED_FILES='formulas/winnow.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: unrelated workflow change skips validation" {
	export CHANGED_FILES=$'.github/workflows/ci.yml\n.github/workflows/pr-auto-assign.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: docs-only change skips validation" {
	export CHANGED_FILES=$'README.md\npyproject.toml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: empty base sha defaults to validation" {
	export BASE_SHA=""
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
}
