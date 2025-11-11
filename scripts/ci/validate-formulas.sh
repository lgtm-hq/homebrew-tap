#!/usr/bin/env bash
set -euo pipefail

# Validate all Homebrew formulas in this tap:
# - Show environment details
# - Run brew style on each formula (path-based)
# - Ensure the tap is added
# - Run brew audit on each formula (tap-qualified name)
# - Install from source for a smoke test and try to print version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Environment:"
sw_vers || true
brew --version || true
ruby --version || true
echo ""

# Derive tap owner and name
owner="${GITHUB_REPOSITORY_OWNER:-}"
repo_full="${GITHUB_REPOSITORY:-}"
repo_name=""

if [[ -z "${owner}" && -n "${repo_full}" ]]; then
  owner="${repo_full%%/*}"
fi
if [[ -z "${repo_full}" ]]; then
  if git -C "${REPO_ROOT}" remote get-url origin >/dev/null 2>&1; then
    remote_url="$(git -C "${REPO_ROOT}" remote get-url origin)"
    if [[ "${remote_url}" =~ github.com[/:]([^/]+)/([^/]+)(\.git)?$ ]]; then
      owner="${owner:-${BASH_REMATCH[1]}}"
      repo_name="${BASH_REMATCH[2]}"
    fi
  fi
fi

repo_name="${repo_name:-${repo_full##*/}}"
tap_short="${repo_name#homebrew-}"
tap="${owner}/${tap_short}"

echo "Using tap: ${tap}"
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

echo "Ensuring tap is available..."
brew tap "${tap}" || true
echo ""

echo "Running brew audit on tap-qualified names..."
for formula in "${formulas[@]}"; do
  formula_name="$(basename "${formula}" .rb)"
  echo "  Audit: ${tap}/${formula_name}"
  brew audit --strict --online "${tap}/${formula_name}"
done
echo ""

echo "Installing from source for smoke test..."
for formula in "${formulas[@]}"; do
  formula_name="$(basename "${formula}" .rb)"
  echo "  Install from source: ${formula}"
  brew install --build-from-source "${formula}"
  if command -v "${formula_name}" >/dev/null 2>&1; then
    echo "  Running ${formula_name} --version"
    "${formula_name}" --version || "${formula_name}" version || true
  fi
done
echo ""

echo "Validation completed successfully."


