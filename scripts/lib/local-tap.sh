#!/usr/bin/env bash
# local-tap.sh - Local Homebrew tap management for testing
#
# Creates a symlink from the repo to Homebrew's tap directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Tap configuration
LOCAL_TAP_NAME="local/test-tap"
LOCAL_TAP_DIR=""

# =============================================================================
# Tap Management Functions
# =============================================================================

# Get the tap directory path
get_tap_dir() {
	echo "$(brew --repository)/Library/Taps/local/homebrew-test-tap"
}

# Set up local tap by symlinking repository
# Usage: setup_local_tap "/path/to/repo"
setup_local_tap() {
	local repo_root="$1"

	LOCAL_TAP_DIR=$(get_tap_dir)
	log_info "Setting up local tap at $LOCAL_TAP_DIR"

	mkdir -p "$(dirname "$LOCAL_TAP_DIR")"
	rm -rf "$LOCAL_TAP_DIR"
	ln -sf "$repo_root" "$LOCAL_TAP_DIR"

	log_success "Local tap created: $LOCAL_TAP_NAME"
}

# Clean up local tap
cleanup_local_tap() {
	LOCAL_TAP_DIR=$(get_tap_dir)
	if [[ -L "$LOCAL_TAP_DIR" ]] || [[ -d "$LOCAL_TAP_DIR" ]]; then
		log_info "Cleaning up local tap..."
		rm -rf "$LOCAL_TAP_DIR"
		rmdir "$(dirname "$LOCAL_TAP_DIR")" 2>/dev/null || true
		log_success "Local tap cleaned up"
	fi
}

# Register cleanup trap
# Usage: register_tap_cleanup
register_tap_cleanup() {
	trap cleanup_local_tap EXIT
}

# Get the full formula name for local tap
# Usage: formula_name=$(get_local_formula_name "lintro")
get_local_formula_name() {
	local formula="$1"
	echo "$LOCAL_TAP_NAME/$formula"
}

# =============================================================================
# Formula Operations
# =============================================================================

# Install a formula from the local tap
# Usage: install_local_formula "lintro"
install_local_formula() {
	local formula="$1"
	local full_name
	full_name=$(get_local_formula_name "$formula")

	log_info "Installing $full_name from source..."

	# Note: pydantic_core wheels may trigger dylib ID warnings (non-zero exit)
	# Install continues successfully, so we verify by checking the binary
	if brew install --build-from-source "$full_name"; then
		log_success "$full_name installed successfully"
		return 0
	else
		log_warning "brew install returned non-zero (may be dylib warnings)"
		return 0 # Continue to verification
	fi
}

# Resolve the CLI binary name for a formula
# Some formulas install under a different binary name (e.g., lintro-bin -> lintro)
# Usage: cmd=$(get_formula_command "lintro-bin")
get_formula_command() {
	local formula="$1"
	local cellar_bin
	cellar_bin="$(brew --cellar)/$formula"

	# Find the actual binary in the formula's Cellar bin directory
	if [[ -d "$cellar_bin" ]]; then
		local bin_dir
		bin_dir=$(find "$cellar_bin" -maxdepth 2 -type d -name bin -print -quit)
		if [[ -n "$bin_dir" ]]; then
			local binary
			binary=$(find "$bin_dir" -maxdepth 1 -type f -perm -111 -print -quit)
			if [[ -n "$binary" ]]; then
				basename "$binary"
				return 0
			fi
		fi
	fi

	# Fall back to formula name
	echo "$formula"
}

# Verify a formula installation works
# Usage: verify_formula "lintro"
verify_formula() {
	local formula="$1"
	local cmd
	cmd=$(get_formula_command "$formula")

	if ! command -v "$cmd" >/dev/null 2>&1; then
		log_error "$cmd command not found after install (formula: $formula)"
		return 1
	fi

	log_info "Running $cmd --version"
	if "$cmd" --version; then
		log_success "$formula ($cmd) verified successfully"
		return 0
	else
		log_error "$cmd --version failed"
		return 1
	fi
}
