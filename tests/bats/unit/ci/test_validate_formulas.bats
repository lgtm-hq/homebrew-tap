#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for validate-formulas.sh conflict-safe install/uninstall flow.

load "../../../helpers/common"
load "../../../helpers/mocks"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	mock_brew "$TEST_TEMP_DIR/mock-bin"
	# lintro and lintro-full declare conflicts_with each other (#144): the
	# mock refuses to install one while the other is still installed.
	export MOCK_BREW_CONFLICTS="lintro:lintro-full"
}

teardown() {
	teardown_temp_dir
}

log_line_number() {
	grep -n "$1" "$MOCK_BREW_LOG" | head -1 | cut -d: -f1
}

# =============================================================================
# validate-formulas.sh end-to-end (mocked brew)
# =============================================================================

@test "validate-formulas: conflicting formulae pass via uninstall between installs" {
	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Validation completed successfully."* ]]

	# Each formula must be uninstalled before the next conflicting install:
	# lintro-full.rb sorts before lintro.rb, so its uninstall has to precede
	# the lintro install.
	uninstall_full="$(log_line_number "^uninstall --force lintro-full$")"
	install_lintro="$(log_line_number "^install --build-from-source local/test-tap/lintro$")"
	[ -n "$uninstall_full" ]
	[ -n "$install_lintro" ]
	[ "$uninstall_full" -lt "$install_lintro" ]

	# Every installed formula is brew-tested while installed and
	# uninstalled again afterwards (none left behind).
	for formula in "$REPO_ROOT"/Formula/*.rb; do
		name="$(basename "$formula" .rb)"
		test_line="$(log_line_number "^test local/test-tap/${name}$")"
		uninstall_line="$(log_line_number "^uninstall --force ${name}$")"
		[ -n "$test_line" ]
		[ -n "$uninstall_line" ]
		[ "$test_line" -lt "$uninstall_line" ]
	done
}

@test "validate-formulas: uninstalls formula even when verification fails" {
	# lintro-full.rb sorts first; a failed verification must still uninstall
	# it, or a retry hits the conflicts_with install refusal again.
	export MOCK_BREW_BROKEN_VERIFY="lintro-full"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	grep -q "^uninstall --force lintro-full$" "$MOCK_BREW_LOG"
}

@test "validate-formulas: fails when a formula's brew test fails" {
	export MOCK_BREW_FAIL_TEST="lintro-full"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"brew test failed for lintro-full"* ]]
	# A failed brew test must still uninstall the formula (conflicts_with).
	grep -q "^uninstall --force lintro-full$" "$MOCK_BREW_LOG"
}

@test "validate-formulas: fails loudly when an uninstall fails" {
	export MOCK_BREW_FAIL_UNINSTALL="lintro-full"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to uninstall lintro-full"* ]]
}

# =============================================================================
# local-tap.sh uninstall_local_formula
# =============================================================================

@test "uninstall_local_formula: succeeds and logs" {
	# shellcheck source=../../../../scripts/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/lib/local-tap.sh"

	run uninstall_local_formula lintro

	[ "$status" -eq 0 ]
	[[ "$output" == *"lintro uninstalled"* ]]
	grep -q "^uninstall --force lintro$" "$MOCK_BREW_LOG"
}

@test "uninstall_local_formula: surfaces brew uninstall failure" {
	export MOCK_BREW_FAIL_UNINSTALL="lintro"
	# shellcheck source=../../../../scripts/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/lib/local-tap.sh"

	run uninstall_local_formula lintro

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to uninstall lintro"* ]]
}
