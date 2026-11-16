#!/usr/bin/env bash
# check-version-drift.sh - Check for version drift between formulas and PyPI
#
# Compares each formula's version with the current release of the package it
# is generated from. Supports both PyPI-based formulas (url pattern) and
# binary formulas (version field).
#
# Usage:
#   check-version-drift.sh --all
#       Check every formula of every product config under formulas/*.yml.
#   check-version-drift.sh <formula-name> <pypi-package>
#       Check one formula against one package.
#
# There is no default product: a call that names nothing is an error.
#
# Outputs:
#   drift_report  JSON list, one row per formula:
#                 {product, package, formula, formula_version, pypi_version, drift}
#   has_drift     true when any row has drifted
#
# Environment:
#   FORMULA_CONFIG_DIR  product configs (default: <repo>/formulas)
#   FORMULA_DIR         formula files (default: <repo>/Formula)
#   PYPI_FIXTURE_DIR    read PyPI JSON from fixtures (tests)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091 # Dynamic SCRIPT_DIR source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="${FORMULA_CONFIG_DIR:-$REPO_ROOT/formulas}"
FORMULA_DIR="${FORMULA_DIR:-$REPO_ROOT/Formula}"

usage() {
	cat >&2 <<'EOF'
Usage:
  check-version-drift.sh --all
  check-version-drift.sh <formula-name> <pypi-package>
EOF
}

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

# Latest release of a package, through the shared PyPI reader so tests can
# answer from PYPI_FIXTURE_DIR.
fetch_pypi_version() {
	local package="$1"
	PYTHONPATH="$SCRIPT_DIR${PYTHONPATH:+:$PYTHONPATH}" python3 -c \
		"import sys; from pypi_utils import fetch_pypi_json; print(fetch_pypi_json(sys.argv[1])['info']['version'])" \
		"$package"
}

# Rows are collected as tab-separated lines: product, package, formula.
TARGETS=()

if [[ $# -eq 0 ]]; then
	log_error "No product selected: pass --all, or a formula name and its PyPI package"
	usage
	exit 2
elif [[ "$1" == "--all" ]]; then
	if [[ $# -ne 1 ]]; then
		log_error "--all takes no further arguments: products come from ${CONFIG_DIR}"
		usage
		exit 2
	fi
	shopt -s nullglob
	CONFIGS=("$CONFIG_DIR"/*.yml "$CONFIG_DIR"/*.yaml)
	shopt -u nullglob
	if [[ ${#CONFIGS[@]} -eq 0 ]]; then
		log_error "No product configs found in ${CONFIG_DIR}"
		exit 1
	fi
	for CONFIG in "${CONFIGS[@]}"; do
		PRODUCT="$(basename "$CONFIG")"
		PRODUCT="${PRODUCT%.*}"
		FORMULA_KEYS=()
		while IFS= read -r line; do
			[[ -n "$line" ]] && FORMULA_KEYS+=("$line")
		done < <(python3 "$SCRIPT_DIR/read_formula_config.py" "$CONFIG" --list-formulas)
		if [[ ${#FORMULA_KEYS[@]} -eq 0 ]]; then
			log_error "Product config defines no formulas: $CONFIG"
			exit 1
		fi
		for FORMULA_KEY in "${FORMULA_KEYS[@]}"; do
			PACKAGE=$(python3 "$SCRIPT_DIR/read_formula_config.py" "$CONFIG" \
				--formula-key "$FORMULA_KEY" --json |
				python3 -c "import json, sys; print(json.load(sys.stdin).get('package') or '')")
			if [[ -z "$PACKAGE" ]]; then
				log_error "No package configured for formula ${FORMULA_KEY} in $CONFIG"
				exit 1
			fi
			TARGETS+=("${PRODUCT}"$'\t'"${PACKAGE}"$'\t'"${FORMULA_KEY}")
		done
	done
else
	if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
		log_error "A single check needs a formula name and its PyPI package"
		usage
		exit 2
	fi
	TARGETS+=("$2"$'\t'"$2"$'\t'"$1")
fi

HAS_DRIFT="false"
ROWS=()
# One PyPI lookup per package, however many formulas share it.
LAST_PACKAGE=""
PYPI_VERSION=""

for TARGET in "${TARGETS[@]}"; do
	IFS=$'\t' read -r PRODUCT PACKAGE FORMULA_NAME <<<"$TARGET"
	FORMULA_FILE="$FORMULA_DIR/$FORMULA_NAME.rb"

	if [[ ! -f "$FORMULA_FILE" ]]; then
		log_error "Formula not found for ${PRODUCT}: $FORMULA_FILE"
		exit 1
	fi

	if [[ "$PACKAGE" != "$LAST_PACKAGE" ]]; then
		if ! PYPI_VERSION=$(fetch_pypi_version "$PACKAGE") || [[ -z "$PYPI_VERSION" ]]; then
			log_error "Could not fetch PyPI version for ${PACKAGE}"
			exit 1
		fi
		LAST_PACKAGE="$PACKAGE"
	fi

	FORMULA_VERSION=$(extract_formula_version "$FORMULA_FILE")

	if [[ "$FORMULA_VERSION" == "$PYPI_VERSION" ]]; then
		DRIFT="false"
		log_success "$FORMULA_NAME matches PyPI ($PACKAGE): $FORMULA_VERSION"
	else
		DRIFT="true"
		HAS_DRIFT="true"
		log_warning "Version drift ($FORMULA_NAME): formula=$FORMULA_VERSION, PyPI ($PACKAGE)=$PYPI_VERSION"
	fi
	ROWS+=("${PRODUCT}"$'\t'"${PACKAGE}"$'\t'"${FORMULA_NAME}"$'\t'"${FORMULA_VERSION}"$'\t'"${PYPI_VERSION}"$'\t'"${DRIFT}")
done

DRIFT_REPORT=$(printf '%s\n' "${ROWS[@]}" | python3 -c '
import json
import sys

rows = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    product, package, formula, formula_version, pypi_version, drift = line.split("\t")
    rows.append(
        {
            "product": product,
            "package": package,
            "formula": formula,
            "formula_version": formula_version,
            "pypi_version": pypi_version,
            "drift": drift == "true",
        }
    )
print(json.dumps(rows, separators=(",", ":")))
')

set_github_output "drift_report" "$DRIFT_REPORT"
set_github_output "has_drift" "$HAS_DRIFT"
