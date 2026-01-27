#!/usr/bin/env bash
# validate-formulas.sh - Validate all Homebrew formulas in this tap
#
# Performs: style checking, source installation, and verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
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
