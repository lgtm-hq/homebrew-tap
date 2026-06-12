#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Resolve and source lgtm-ci publish tooling for tap scripts.

# shellcheck disable=SC2034
LGTM_CI_TOOLING_REF="${LGTM_CI_TOOLING_REF:-375d104f6ca707f4f35344170a42bf901a617a9f}"

resolve_lgtm_ci_tooling_dir() {
	local repo_root="${1:-}"

	if [[ -n "${LGTM_CI_TOOLING_DIR:-}" && -f "${LGTM_CI_TOOLING_DIR}/scripts/ci/lib/publish.sh" ]]; then
		echo "${LGTM_CI_TOOLING_DIR}"
		return 0
	fi

	if [[ -n "$repo_root" && -f "$repo_root/.lgtm-ci-tooling/scripts/ci/lib/publish.sh" ]]; then
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
