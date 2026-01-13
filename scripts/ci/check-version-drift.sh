#!/usr/bin/env bash
set -euo pipefail

# Check for version drift between formula and PyPI
# Outputs: formula_version, pypi_version, has_drift (true/false)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FORMULA_NAME="${1:-lintro}"
PYPI_PACKAGE="${2:-lintro}"

FORMULA_FILE="${REPO_ROOT}/Formula/${FORMULA_NAME}.rb"

if [[ ! -f "${FORMULA_FILE}" ]]; then
  echo "Error: Formula not found: ${FORMULA_FILE}" >&2
  exit 1
fi

# Extract formula version from URL
FORMULA_VERSION=$(grep -E '^\s+url\s+"https://files.pythonhosted.org' "${FORMULA_FILE}" | \
  sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz.*/\1/')

if [[ -z "${FORMULA_VERSION}" ]]; then
  echo "Error: Could not extract version from formula" >&2
  exit 1
fi

# Get latest PyPI version
PYPI_VERSION=$(curl -sf "https://pypi.org/pypi/${PYPI_PACKAGE}/json" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])")

if [[ -z "${PYPI_VERSION}" ]]; then
  echo "Error: Could not fetch PyPI version" >&2
  exit 1
fi

# Compare versions
if [[ "${FORMULA_VERSION}" == "${PYPI_VERSION}" ]]; then
  HAS_DRIFT="false"
else
  HAS_DRIFT="true"
fi

# Output results
echo "formula_version=${FORMULA_VERSION}"
echo "pypi_version=${PYPI_VERSION}"
echo "has_drift=${HAS_DRIFT}"

# Also output for GitHub Actions if running in CI
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "formula_version=${FORMULA_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "pypi_version=${PYPI_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "has_drift=${HAS_DRIFT}" >> "${GITHUB_OUTPUT}"
fi
