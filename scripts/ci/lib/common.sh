#!/usr/bin/env bash
# common.sh - Shared utilities for homebrew-tap scripts

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

# =============================================================================
# GitHub Actions Integration
# =============================================================================

# Set a GitHub Actions output variable
# Usage: set_github_output "key" "value"
set_github_output() {
	local key="$1"
	local value="$2"
	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		echo "$key=$value" >>"$GITHUB_OUTPUT"
	fi
	# Also echo for local testing
	echo "$key=$value"
}

# =============================================================================
# Environment Detection
# =============================================================================

# Check if running in CI environment
is_ci() {
	[[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Get repository root (assumes script is sourced from scripts/ subdirectory)
get_repo_root() {
	local script_dir
	script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
	(cd "$script_dir" && git rev-parse --show-toplevel 2>/dev/null) || dirname "$(dirname "$script_dir")"
}

# =============================================================================
# Verification bypass (local regeneration only)
# =============================================================================

# Decide whether asset/provenance verification may be skipped.
# Usage: resolve_skip_asset_verify <flag-given:true|false>
# Prints "true" or "false". The bypass is accepted only outside GitHub
# Actions, and only as the explicit --skip-asset-verify flag or the literal
# SKIP_ASSET_VERIFY=1; any other value, or any use under GITHUB_ACTIONS, is
# a hard error (lgtm-hq/homebrew-tap#471).
resolve_skip_asset_verify() {
	local flag_given="${1:-false}"
	local env_value="${SKIP_ASSET_VERIFY:-}"

	if [[ "$flag_given" != "true" && -z "$env_value" ]]; then
		printf 'false\n'
		return 0
	fi
	if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
		log_error "Refusing to skip asset verification under GitHub Actions (SKIP_ASSET_VERIFY / --skip-asset-verify are for local regeneration only)"
		return 1
	fi
	if [[ "$flag_given" != "true" && "$env_value" != "1" ]]; then
		log_error "SKIP_ASSET_VERIFY must be exactly 1 to skip asset verification (got '${env_value}'); unset it to verify"
		return 1
	fi
	# stderr: callers capture stdout for the verdict.
	log_warning "ASSET VERIFICATION DISABLED: skipping download/sha256/attestation/provenance checks (local regeneration only; never commit output generated this way without regenerating in CI)" >&2
	printf 'true\n'
}
