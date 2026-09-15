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
