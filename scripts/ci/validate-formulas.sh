#!/usr/bin/env bash
# validate-formulas.sh - Validate all Homebrew formulas in this tap
#
# Performs: style checking, source installation, and verification

set -euo pipefail

# Read formulae from the on-disk local tap rather than the Homebrew API so the
# copied test tap is loaded.
export HOMEBREW_NO_INSTALL_FROM_API=1
# Recent Homebrew requires explicit tap trust before loading formulae from a
# non-official tap. This local test tap is built from the repo under test, so
# disable the interactive trust gate for the validation run.
# See https://docs.brew.sh/Tap-Trust
export HOMEBREW_NO_REQUIRE_TAP_TRUST=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091 # Dynamic SCRIPT_DIR source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/local-tap.sh disable=SC1091 # Dynamic SCRIPT_DIR source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$SCRIPT_DIR/../lib/local-tap.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Show environment info
log_info "Environment:"
sw_vers 2>/dev/null || true
brew --version 2>/dev/null || true
ruby --version 2>/dev/null || true
echo ""

# Find formulas
shopt -s nullglob
formulas=("$REPO_ROOT"/Formula/*.rb)
if [[ ${#formulas[@]} -eq 0 ]]; then
	log_error "No formulas found in $REPO_ROOT/Formula"
	exit 1
fi

# Style check
log_info "Running brew style on formula files..."
for formula in "${formulas[@]}"; do
	log_info "  Style: $formula"
	brew style "$formula"
done
echo ""

# Set up local tap and register cleanup
setup_local_tap "$REPO_ROOT"
register_tap_cleanup
echo ""

# Install and verify each formula
log_info "Installing from source for smoke test..."
for formula in "${formulas[@]}"; do
	formula_name="$(basename "$formula" .rb)"
	install_local_formula "$formula_name"
	verify_formula "$formula_name" || exit 1
done
echo ""

log_success "Validation completed successfully."
