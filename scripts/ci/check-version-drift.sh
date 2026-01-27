#!/usr/bin/env bash
# check-version-drift.sh - Check for version drift between formula and PyPI
#
# Outputs: formula_version, pypi_version, has_drift (true/false)
# Usage: check-version-drift.sh [formula-name] [pypi-package]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FORMULA_NAME="${1:-lintro}"
PYPI_PACKAGE="${2:-lintro}"
FORMULA_FILE="$REPO_ROOT/Formula/$FORMULA_NAME.rb"

if [[ ! -f "$FORMULA_FILE" ]]; then
	log_error "Formula not found: $FORMULA_FILE"
	exit 1
fi

# Extract formula version from URL pattern (supports pre-release like 1.0.0rc1)
FORMULA_VERSION=$(grep -E '^\s+url\s+"https://files.pythonhosted.org' "$FORMULA_FILE" |
	sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+[^"]*)\.tar\.gz.*/\1/')

if [[ -z "$FORMULA_VERSION" ]]; then
	log_error "Could not extract version from formula"
	exit 1
fi

# Get latest PyPI version
if ! PYPI_VERSION=$(curl -sf "https://pypi.org/pypi/$PYPI_PACKAGE/json" |
	python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])"); then
	log_error "Could not fetch PyPI version"
	exit 1
fi

# Compare versions
if [[ "$FORMULA_VERSION" == "$PYPI_VERSION" ]]; then
	HAS_DRIFT="false"
	log_success "Versions match: $FORMULA_VERSION"
else
	HAS_DRIFT="true"
	log_warning "Version drift: formula=$FORMULA_VERSION, PyPI=$PYPI_VERSION"
fi

# Output results
set_github_output "formula_version" "$FORMULA_VERSION"
set_github_output "pypi_version" "$PYPI_VERSION"
set_github_output "has_drift" "$HAS_DRIFT"
