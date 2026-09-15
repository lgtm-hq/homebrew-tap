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
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run uninstall_local_formula lintro

	[ "$status" -eq 0 ]
	[[ "$output" == *"lintro uninstalled"* ]]
	grep -q "^uninstall --force lintro$" "$MOCK_BREW_LOG"
}

@test "uninstall_local_formula: surfaces brew uninstall failure" {
	export MOCK_BREW_FAIL_UNINSTALL="lintro"
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run uninstall_local_formula lintro

	[ "$status" -ne 0 ]
	[[ "$output" == *"Failed to uninstall lintro"* ]]
}

# =============================================================================
# install failure propagation and brew audit (#471)
# =============================================================================

@test "validate-formulas: fails when a formula does not install" {
	export MOCK_BREW_FAIL_INSTALL="lintro-full"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"brew install failed for local/test-tap/lintro-full"* ]]
	[[ "$output" == *"Validation failed: lintro-full does not install"* ]]
	# Nothing after the failed install runs for that formula.
	! grep -q "^audit --strict --online local/test-tap/lintro-full$" "$MOCK_BREW_LOG"
	! grep -q "^test local/test-tap/lintro-full$" "$MOCK_BREW_LOG"
}

@test "validate-formulas: runs brew audit --strict --online on every formula" {
	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -eq 0 ]
	for formula in "$REPO_ROOT"/Formula/*.rb; do
		name="$(basename "$formula" .rb)"
		install_line="$(log_line_number "^install --build-from-source local/test-tap/${name}$")"
		audit_line="$(log_line_number "^audit --strict --online local/test-tap/${name}$")"
		test_line="$(log_line_number "^test local/test-tap/${name}$")"
		[ -n "$audit_line" ]
		[ "$install_line" -lt "$audit_line" ]
		[ "$audit_line" -lt "$test_line" ]
	done
}

@test "validate-formulas: an unaccepted audit finding fails and uninstalls" {
	export MOCK_BREW_AUDIT_FINDINGS="* C: 12: col 3: FormulaAudit/Desc: Description should not start with the formula name"
	export MOCK_BREW_AUDIT_FORMULA="lintro-full"
	export AUDIT_ACCEPTED_WARNINGS="Version 'v' not found in URL"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Unaccepted audit finding: C: 12: col 3: FormulaAudit/Desc"* ]]
	[[ "$output" == *"brew audit failed for lintro-full"* ]]
	grep -q "^uninstall --force lintro-full$" "$MOCK_BREW_LOG"
}

@test "validate-formulas: accepted audit findings are reported but tolerated" {
	export MOCK_BREW_AUDIT_FINDINGS="* Version 'v' not found in URL"
	export AUDIT_ACCEPTED_WARNINGS="Version 'v' not found in URL"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Accepted audit finding: Version 'v' not found in URL"* ]]
	[[ "$output" == *"Validation completed successfully."* ]]
}

# =============================================================================
# local-tap.sh install_local_formula / audit_local_formula
# =============================================================================

@test "install_local_formula: propagates brew install failure" {
	export MOCK_BREW_FAIL_INSTALL="lintro"
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run install_local_formula lintro

	[ "$status" -eq 1 ]
	[[ "$output" == *"brew install failed for local/test-tap/lintro"* ]]
}

@test "install_local_formula: succeeds when brew install succeeds" {
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run install_local_formula lintro

	[ "$status" -eq 0 ]
	[[ "$output" == *"installed successfully"* ]]
}

@test "audit_local_formula: mixed accepted and unaccepted findings fail" {
	export MOCK_BREW_AUDIT_FINDINGS=$'* Version \'v\' not found in URL\n* Stable: some new problem'
	export AUDIT_ACCEPTED_WARNINGS="Version 'v' not found in URL"
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run audit_local_formula lintro

	[ "$status" -eq 1 ]
	[[ "$output" == *"Accepted audit finding: Version 'v' not found in URL"* ]]
	[[ "$output" == *"Unaccepted audit finding: Stable: some new problem"* ]]
}

@test "audit_local_formula: passes with an empty accept list and a clean audit" {
	export AUDIT_ACCEPTED_WARNINGS=""
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run audit_local_formula lintro

	[ "$status" -eq 0 ]
	[[ "$output" == *"lintro brew audit passed"* ]]
}

@test "validate-formulas: ships with no accepted audit findings by default" {
	unset AUDIT_ACCEPTED_WARNINGS
	export MOCK_BREW_AUDIT_FINDINGS="* Version 'v' not found in URL"

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Unaccepted audit finding: Version 'v' not found in URL"* ]]
}

@test "audit_local_formula: nonzero exit without findings fails (tool crash)" {
	export MOCK_BREW_AUDIT_CRASH=1
	export AUDIT_ACCEPTED_WARNINGS=""
	# shellcheck source=../../../../scripts/ci/lib/local-tap.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/local-tap.sh"

	run audit_local_formula lintro

	[ "$status" -eq 1 ]
	[[ "$output" == *"Command Line Tools are too outdated"* ]]
	[[ "$output" == *"brew audit exited 1 for lintro without any findings to evaluate"* ]]
}

@test "validate-formulas: a crashing brew audit fails the run" {
	export MOCK_BREW_AUDIT_CRASH=1

	run bash "$REPO_ROOT/scripts/ci/validate-formulas.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"without any findings to evaluate"* ]]
	grep -q "^uninstall --force lintro-full$" "$MOCK_BREW_LOG"
}
