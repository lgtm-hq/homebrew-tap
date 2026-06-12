#!/usr/bin/env bash
# wait-for-pypi.sh
# Wait for a package version to be available on PyPI via lgtm-ci registry helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/lgtm-ci-tooling.sh disable=SC1091
source "$SCRIPT_DIR/../lib/lgtm-ci-tooling.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	cat <<'EOF'
Wait for a package version to be available on PyPI.

Usage: wait-for-pypi.sh <package-name> <version> [max-wait-seconds]

Arguments:
  package-name      The package name on PyPI (e.g., lintro)
  version           The version to wait for (e.g., 1.0.0)
  max-wait-seconds  Maximum wait time in seconds (default: 600)

Environment:
  LGTM_CI_TOOLING_DIR  Path to sparse lgtm-ci checkout (optional)
EOF
	exit 0
fi

PACKAGE_NAME="${1:?Package name is required}"
VERSION="${2:?Version is required}"
MAX_WAIT_SECONDS="${3:-${PYPI_MAX_WAIT_SECONDS:-600}}"

source_lgtm_ci_publish "$REPO_ROOT"

if wait_for_package "pypi" "$PACKAGE_NAME" "$VERSION" "$MAX_WAIT_SECONDS" "false"; then
	log_success "Package ${PACKAGE_NAME} ${VERSION} is available on PyPI"
else
	log_error "Timeout waiting for ${PACKAGE_NAME} ${VERSION} on PyPI"
	exit 1
fi
