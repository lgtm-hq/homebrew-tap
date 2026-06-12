#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Resolve and source lgtm-ci publish tooling for tap scripts.

# shellcheck disable=SC2034
LGTM_CI_TOOLING_REF="${LGTM_CI_TOOLING_REF:-ba485556d3d4605b825347c2fe431ad4395b1c63}"

_lgtm_ci_tooling_ready() {
	local dir="$1"
	[[ -f "$dir/scripts/ci/lib/publish.sh" && -f "$dir/scripts/ci/lib/actions.sh" ]]
}

resolve_lgtm_ci_tooling_dir() {
	local repo_root="${1:-}"

	if [[ -n "${LGTM_CI_TOOLING_DIR:-}" ]] && _lgtm_ci_tooling_ready "${LGTM_CI_TOOLING_DIR}"; then
		echo "${LGTM_CI_TOOLING_DIR}"
		return 0
	fi

	if [[ -n "$repo_root" ]] && _lgtm_ci_tooling_ready "$repo_root/.lgtm-ci-tooling"; then
		echo "$repo_root/.lgtm-ci-tooling"
		return 0
	fi

	return 1
}

source_lgtm_ci_publish() {
	local repo_root="${1:-}"
	local tooling_dir=""

	tooling_dir="$(resolve_lgtm_ci_tooling_dir "$repo_root")" || {
		echo "[ERROR] lgtm-ci tooling not found. Run scripts/ci/ensure-lgtm-ci-tooling.sh or set LGTM_CI_TOOLING_DIR." >&2
		return 1
	}

	# shellcheck source=/dev/null
	source "$tooling_dir/scripts/ci/lib/actions.sh"
	# shellcheck source=/dev/null
	source "$tooling_dir/scripts/ci/lib/publish.sh"
}
