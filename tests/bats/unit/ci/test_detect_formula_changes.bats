#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for detect-formula-changes.sh path decision logic.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	unset BASE_SHA HEAD_SHA CHANGED_FILES LGTM_CI_RUNNER
	REPO_ROOT="$(repo_root)"
	GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output"
	export GITHUB_OUTPUT
}

teardown() {
	teardown_temp_dir
}

@test "detect-formula-changes: formula file requires validation" {
	export CHANGED_FILES=$'Formula/lintro.rb\nREADME.md'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: script change requires validation" {
	export CHANGED_FILES='scripts/ci/generate-binary-formula.sh'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: config change requires validation" {
	export CHANGED_FILES='formulas/winnow.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: unrelated workflow change skips validation" {
	export CHANGED_FILES=$'.github/workflows/ci.yml\n.github/workflows/pr-auto-assign.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: docs-only change skips validation" {
	export CHANGED_FILES=$'README.md\npyproject.toml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: empty generic runner falls back to Ubuntu" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER=''
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: no-op uses supplied generic runner" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=custom-ubuntu-runner$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: supplied runner is literal data" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER='${{ vars.UNTRUSTED }}$(exit 99)'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -Fxq "runner=$LGTM_CI_RUNNER" "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: non-formula merge-group diff skips macOS" {
	export BASE_SHA='merge-base'
	export HEAD_SHA='merge-head'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	git() {
		[ "$*" = 'diff --name-only merge-base...merge-head' ] || return 1
		printf '%s\n' README.md
	}
	export -f git
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=custom-ubuntu-runner$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: empty push/dispatch base defaults to macOS" {
	export BASE_SHA=""
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: unset push/dispatch base defaults to macOS" {
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}
