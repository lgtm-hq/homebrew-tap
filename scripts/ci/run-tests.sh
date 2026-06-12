#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Run shell tests locally with lgtm-ci tooling and optional coverage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COVERAGE_DIR="$REPO_ROOT/coverage"

if ! command -v bats &>/dev/null; then
	echo "bats is required but not installed" >&2
	exit 1
fi

# shellcheck source=../helpers/common.bash disable=SC1091
source "$REPO_ROOT/tests/helpers/common.bash"
bootstrap_test_env "$REPO_ROOT"

if command -v kcov &>/dev/null; then
	mkdir -p "$COVERAGE_DIR"
	kcov --exclude-pattern='/usr,/opt/homebrew,tests' "$COVERAGE_DIR" \
		bats --recursive "$REPO_ROOT/tests/bats"
	echo "Coverage report: $COVERAGE_DIR/index.html"
else
	bats --recursive "$REPO_ROOT/tests/bats"
	echo "Coverage: kcov not installed; ran tests without coverage report"
fi
