#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for FormulaAudit/Desc validation helper.

load "../../../helpers/common"

setup() {
	REPO_ROOT="$(repo_root)"
	ensure_test_python_deps "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
}

@test "formula_description: accepts description without leading formula name" {
	run python3 "$SCRIPTS_DIR/formula_description.py" winnow \
		"Organize, deduplicate, and keep the best from your media library"

	[ "$status" -eq 0 ]
}

@test "formula_description: rejects description starting with formula name" {
	run python3 "$SCRIPTS_DIR/formula_description.py" winnow \
		"Winnow your media library — organize, deduplicate, keep the best"

	[ "$status" -eq 1 ]
	[[ "$output" == *"FormulaAudit/Desc"* ]]
}

@test "formula_description: rejects hyphenated formula key prefix" {
	run python3 "$SCRIPTS_DIR/formula_description.py" lintro-full \
		"Lintro-full bundle with all tools"

	[ "$status" -eq 1 ]
	[[ "$output" == *"FormulaAudit/Desc"* ]]
}

@test "formula_description: rejects empty description" {
	run python3 "$SCRIPTS_DIR/formula_description.py" winnow ""

	[ "$status" -eq 1 ]
	[[ "$output" == *"must not be empty"* ]]
}

@test "formula_description: rejects whitespace-only description" {
	run python3 "$SCRIPTS_DIR/formula_description.py" winnow "   "

	[ "$status" -eq 1 ]
	[[ "$output" == *"must not be empty"* ]]
}

@test "formula_description: rejects apostrophe after formula name" {
	run python3 "$SCRIPTS_DIR/formula_description.py" winnow \
		"Winnow's media library organizer"

	[ "$status" -eq 1 ]
	[[ "$output" == *"FormulaAudit/Desc"* ]]
}
