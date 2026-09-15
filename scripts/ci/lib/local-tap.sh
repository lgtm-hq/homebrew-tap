#!/usr/bin/env bash
# local-tap.sh - Local Homebrew tap management for testing
#
# Creates a symlink from the repo to Homebrew's tap directory

# Private name: callers (validate-formulas.sh) own SCRIPT_DIR and derive
# their repo root from it after sourcing this library.
_LOCAL_TAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh disable=SC1091 # Dynamic source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$_LOCAL_TAP_LIB_DIR/common.sh"

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

# Set up local tap as a real git repository.
#
# Recent Homebrew refuses to load formulae from a symlinked tap
# ("Refusing to load formula ... from untrusted tap"). Copy the tap contents
# into a real directory and initialise a git repo so Homebrew trusts it.
# Usage: setup_local_tap "/path/to/repo"
setup_local_tap() {
	local repo_root="$1"

	LOCAL_TAP_DIR=$(get_tap_dir)
	log_info "Setting up local tap at $LOCAL_TAP_DIR"

	rm -rf "$LOCAL_TAP_DIR"
	mkdir -p "$LOCAL_TAP_DIR/Formula"
	cp "$repo_root"/Formula/*.rb "$LOCAL_TAP_DIR/Formula/"

	# A real (non-symlink) git repo is required for Homebrew to trust the tap.
	git -C "$LOCAL_TAP_DIR" init --quiet
	git -C "$LOCAL_TAP_DIR" add -A
	git -C "$LOCAL_TAP_DIR" \
		-c user.email="ci@local.test" \
		-c user.name="Local Tap CI" \
		-c commit.gpgsign=false \
		commit --quiet -m "Local test tap"

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

	# A non-zero brew install is a failure, full stop. The old "may be dylib
	# warnings" pass-through let a formula that does not install reach the
	# --version smoke check (lgtm-hq/homebrew-tap#471).
	if brew install --build-from-source "$full_name"; then
		log_success "$full_name installed successfully"
		return 0
	fi
	log_error "brew install failed for $full_name"
	return 1
}

# Run brew audit --strict --online on an installed local-tap formula.
# Warnings whose text matches an entry in AUDIT_ACCEPTED_WARNINGS (a
# newline-separated list; see validate-formulas.sh) are reported but do not
# fail the audit; anything else does.
# Usage: audit_local_formula "lintro"
audit_local_formula() {
	local formula="$1"
	local full_name
	full_name=$(get_local_formula_name "$formula")

	log_info "Running brew audit --strict --online $full_name"
	local audit_output audit_status=0
	audit_output="$(brew audit --strict --online "$full_name" 2>&1)" || audit_status=$?
	if [[ -n "$audit_output" ]]; then
		printf '%s\n' "$audit_output"
	fi
	if [[ "$audit_status" -eq 0 ]]; then
		log_success "$formula brew audit passed"
		return 0
	fi

	# Every "* <message>" line must match an accepted pattern for the
	# failure to be tolerated; unmatched findings fail the audit.
	local line unaccepted=0 findings=0 pattern accepted
	while IFS= read -r line; do
		[[ "$line" == "  * "* || "$line" == "* "* ]] || continue
		findings=$((findings + 1))
		accepted=0
		while IFS= read -r pattern; do
			[[ -z "$pattern" ]] && continue
			if [[ "$line" == *"$pattern"* ]]; then
				accepted=1
				break
			fi
		done <<<"${AUDIT_ACCEPTED_WARNINGS:-}"
		if [[ "$accepted" -eq 1 ]]; then
			log_warning "Accepted audit finding: ${line#*\* }"
		else
			log_error "Unaccepted audit finding: ${line#*\* }"
			unaccepted=1
		fi
	done <<<"$audit_output"

	if [[ "$findings" -eq 0 ]]; then
		# Non-zero exit with nothing to parse: brew itself failed (crash,
		# transport error, outdated toolchain). Never treat that as clean.
		log_error "brew audit exited ${audit_status} for $formula without any findings to evaluate"
		return 1
	fi
	if [[ "$unaccepted" -eq 1 ]]; then
		log_error "brew audit failed for $formula"
		return 1
	fi
	log_warning "$formula brew audit exited ${audit_status} with only accepted findings"
	return 0
}

# Run a formula's `test do` block via brew test
# Catches broken test blocks (e.g. escaped interpolation) that a plain
# --version smoke check misses (#145).
# Usage: brew_test_formula "lintro"
brew_test_formula() {
	local formula="$1"
	local full_name
	full_name=$(get_local_formula_name "$formula")

	log_info "Running brew test $full_name"
	if brew test "$full_name"; then
		log_success "$formula brew test passed"
		return 0
	else
		log_error "brew test failed for $formula"
		return 1
	fi
}

# Uninstall a formula installed from the local tap
# The tap's formulae may declare conflicts_with each other (lintro and
# lintro-full both provide the lintro binary), so each formula must be
# uninstalled after verification or the next install is refused with
# "Cannot install ... because conflicting formulae are installed".
# Usage: uninstall_local_formula "lintro"
uninstall_local_formula() {
	local formula="$1"

	log_info "Uninstalling $formula..."
	if brew uninstall --force "$formula"; then
		log_success "$formula uninstalled"
		return 0
	else
		log_error "Failed to uninstall $formula"
		return 1
	fi
}

# Resolve the installed binary path for a formula
# Some formulas install under a different binary name than the formula name
# Returns the absolute path to the binary, or the formula name as fallback
# Usage: cmd=$(get_formula_command "lintro")
get_formula_command() {
	local formula="$1"
	local prefix
	prefix="$(brew --prefix "$formula" 2>/dev/null)" || true

	if [[ -n "$prefix" && -d "$prefix/bin" ]]; then
		local binary
		binary=$(find "$prefix/bin" -maxdepth 1 \( -type f -o -type l \) -perm -111 -print -quit)
		if [[ -n "$binary" ]]; then
			echo "$binary"
			return 0
		fi
	fi

	# Fall back to formula name
	echo "$formula"
}

# Verify a formula installation works
# Usage: verify_formula "lintro"
verify_formula() {
	local formula="$1"
	local installed_cmd
	installed_cmd=$(get_formula_command "$formula")

	if [[ ! -x "$installed_cmd" ]]; then
		log_error "No executable found after install (formula: $formula, expected: $installed_cmd)"
		return 1
	fi

	log_info "Running $installed_cmd --version"
	if "$installed_cmd" --version; then
		log_success "$formula ($(basename "$installed_cmd")) verified successfully"
		return 0
	else
		log_error "$installed_cmd --version failed"
		return 1
	fi
}
