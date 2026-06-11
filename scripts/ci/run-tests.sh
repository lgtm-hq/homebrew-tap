#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Run shell tests with optional coverage reporting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COVERAGE_DIR="$REPO_ROOT/coverage"

if ! command -v bats &>/dev/null; then
	echo "bats is required but not installed" >&2
	exit 1
fi

TEST_VENV="$REPO_ROOT/.test-venv"
if [[ ! -d "$TEST_VENV" ]]; then
	python3 -m venv "$TEST_VENV"
fi
# shellcheck disable=SC1091
source "$TEST_VENV/bin/activate"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r "$REPO_ROOT/requirements-test.txt"

if command -v kcov &>/dev/null; then
	mkdir -p "$COVERAGE_DIR"
	kcov --exclude-pattern='/usr,/opt/homebrew,tests' "$COVERAGE_DIR" \
		bats --recursive "$REPO_ROOT/tests/bats"
	echo "Coverage report: $COVERAGE_DIR/index.html"
else
	bats --recursive "$REPO_ROOT/tests/bats"
	echo "Coverage: kcov not installed; ran tests without coverage report"
fi
