#!/usr/bin/env bash
# check-version-drift.sh - Check for version drift between formula and PyPI
#
# Supports both PyPI-based formulas (url pattern) and binary formulas (version field).
# Outputs: formula_version, pypi_version, has_drift (true/false)
# Usage:
#   check-version-drift.sh [formula-name] [pypi-package]
#   check-version-drift.sh --all [pypi-package]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091 # Dynamic SCRIPT_DIR source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

extract_formula_version() {
	local formula_file="$1"

	local version
	version=$(sed -nE 's/^[[:space:]]*url[[:space:]]+"https:\/\/files\.pythonhosted\.org.*-([0-9]+\.[0-9]+\.[0-9]+[^"]*)\.tar\.gz.*/\1/p' "$formula_file" |
		head -1)

	if [[ -z "$version" ]]; then
		version=$(sed -nE 's/^[[:space:]]*version[[:space:]]+"([^"]+)".*/\1/p' "$formula_file" |
			head -1)
	fi

	if [[ -z "$version" ]]; then
		log_error "Could not extract version from formula: $formula_file"
		return 1
	fi

	echo "$version"
}

if [[ "${1:-}" == "--all" ]]; then
	PYPI_PACKAGE="${2:-lintro}"
	FORMULAS=("lintro" "lintro-full")
else
	FORMULAS=("${1:-lintro}")
	PYPI_PACKAGE="${2:-lintro}"
fi

if ! PYPI_VERSION=$(curl -sf "https://pypi.org/pypi/$PYPI_PACKAGE/json" |
	python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])"); then
	log_error "Could not fetch PyPI version"
	exit 1
fi

HAS_DRIFT="false"
FORMULA_VERSIONS=()

for FORMULA_NAME in "${FORMULAS[@]}"; do
	FORMULA_FILE="$REPO_ROOT/Formula/$FORMULA_NAME.rb"

	if [[ ! -f "$FORMULA_FILE" ]]; then
		log_error "Formula not found: $FORMULA_FILE"
		exit 1
	fi

	FORMULA_VERSION=$(extract_formula_version "$FORMULA_FILE")
	FORMULA_VERSIONS+=("$FORMULA_NAME=$FORMULA_VERSION")

	if [[ "$FORMULA_VERSION" == "$PYPI_VERSION" ]]; then
		log_success "$FORMULA_NAME matches PyPI: $FORMULA_VERSION"
	else
		HAS_DRIFT="true"
		log_warning "Version drift ($FORMULA_NAME): formula=$FORMULA_VERSION, PyPI=$PYPI_VERSION"
	fi
done

if [[ ${#FORMULAS[@]} -eq 1 ]]; then
	FORMULA_VERSION_OUTPUT="${FORMULA_VERSIONS[0]#*=}"
else
	FORMULA_VERSION_OUTPUT=$(printf '%s, ' "${FORMULA_VERSIONS[@]}")
	FORMULA_VERSION_OUTPUT="${FORMULA_VERSION_OUTPUT%, }"
fi

set_github_output "formula_version" "$FORMULA_VERSION_OUTPUT"
set_github_output "pypi_version" "$PYPI_VERSION"
set_github_output "has_drift" "$HAS_DRIFT"
