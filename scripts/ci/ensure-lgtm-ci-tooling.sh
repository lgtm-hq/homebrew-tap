#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Ensure a sparse lgtm-ci checkout exists for local scripts and tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/lgtm-ci-tooling.sh disable=SC1091
source "$SCRIPT_DIR/../lib/lgtm-ci-tooling.sh"

TOOLING_DIR="$REPO_ROOT/.lgtm-ci-tooling"

if _lgtm_ci_tooling_ready "$TOOLING_DIR"; then
	export LGTM_CI_TOOLING_DIR="$TOOLING_DIR"
	exit 0
fi

if ! command -v git &>/dev/null; then
	echo "git is required to fetch lgtm-ci tooling" >&2
	exit 1
fi

echo "Fetching lgtm-ci tooling (${LGTM_CI_TOOLING_REF}) into ${TOOLING_DIR}..."
rm -rf "$TOOLING_DIR"
git clone --filter=blob:none --sparse \
	"https://github.com/lgtm-hq/lgtm-ci.git" \
	"$TOOLING_DIR"
git -C "$TOOLING_DIR" sparse-checkout set \
	.github/actions/harden-runner \
	.github/actions/resolve-egress-allowlist \
	.github/actions/setup-python \
	scripts/ci
git -C "$TOOLING_DIR" checkout "$LGTM_CI_TOOLING_REF"

export LGTM_CI_TOOLING_DIR="$TOOLING_DIR"
