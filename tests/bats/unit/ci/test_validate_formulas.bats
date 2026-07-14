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

	# Every installed formula is uninstalled again (none left behind).
	for formula in "$REPO_ROOT"/Formula/*.rb; do
		name="$(basename "$formula" .rb)"
		grep -q "^uninstall --force ${name}$" "$MOCK_BREW_LOG"
	done
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
	run bash -c "source '$REPO_ROOT/scripts/lib/local-tap.sh' && uninstall_local_formula lintro"

	[ "$status" -eq 0 ]
	[[ "$output" == *"lintro uninstalled"* ]]
	grep -q "^uninstall --force lintro$" "$MOCK_BREW_LOG"
}

@test "uninstall_local_formula: surfaces brew uninstall failure" {
	export MOCK_BREW_FAIL_UNINSTALL="lintro"

	run bash -c "source '$REPO_ROOT/scripts/lib/local-tap.sh' && uninstall_local_formula lintro"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to uninstall lintro"* ]]
}
