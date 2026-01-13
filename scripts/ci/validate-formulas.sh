#!/usr/bin/env bash
set -euo pipefail

# Validate all Homebrew formulas in this tap:
# - Show environment details
# - Run brew style on each formula (linting)
# - Set up local tap for testing
# - Install from source for a smoke test
# - Verify the installed command works

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Environment:"
sw_vers || true
brew --version || true
ruby --version || true
echo ""

shopt -s nullglob
formulas=( "${REPO_ROOT}"/Formula/*.rb )
if [[ ${#formulas[@]} -eq 0 ]]; then
  echo "No formulas found in ${REPO_ROOT}/Formula"
  exit 1
fi

echo "Running brew style on formula files..."
for formula in "${formulas[@]}"; do
  echo "  Style: ${formula}"
  brew style "${formula}"
done
echo ""

# Set up local tap by symlinking the repo to Homebrew's tap directory
TAP_NAME="local/test-tap"
TAP_DIR="$(brew --repository)/Library/Taps/local/homebrew-test-tap"

echo "Setting up local tap at ${TAP_DIR}..."
mkdir -p "$(dirname "${TAP_DIR}")"
rm -rf "${TAP_DIR}"
ln -sf "${REPO_ROOT}" "${TAP_DIR}"
echo ""

echo "Installing from source for smoke test..."
for formula in "${formulas[@]}"; do
  formula_name="$(basename "${formula}" .rb)"
  echo "  Install from source: ${TAP_NAME}/${formula_name}"
  # Note: pydantic_core wheels may trigger dylib ID warnings that cause non-zero exit
  # The install still succeeds, so we verify by checking the binary works
  brew install --build-from-source "${TAP_NAME}/${formula_name}" || true

  # Verify the installation actually worked
  if command -v "${formula_name}" >/dev/null 2>&1; then
    echo "  Running ${formula_name} --version"
    if "${formula_name}" --version; then
      echo "  ✓ ${formula_name} installed successfully"
    else
      echo "  ✗ ${formula_name} --version failed"
      exit 1
    fi
  else
    echo "  ✗ ${formula_name} command not found after install"
    exit 1
  fi
done
echo ""

# Cleanup
echo "Cleaning up local tap..."
rm -rf "${TAP_DIR}"
rmdir "$(dirname "${TAP_DIR}")" 2>/dev/null || true
echo ""

echo "Validation completed successfully."
