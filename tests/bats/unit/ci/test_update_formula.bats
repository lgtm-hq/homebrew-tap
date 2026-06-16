#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for update-formula.sh App token push configuration.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	export SCRIPT_DIR="$REPO_ROOT/scripts/ci"
	# shellcheck source=../../../scripts/lib/common.sh disable=SC1091
	source "$REPO_ROOT/scripts/lib/common.sh"

	local extracted
	extracted="$(sed -n '/^configure_git_push_remote() {/,/^}/p' \
		"$REPO_ROOT/scripts/ci/update-formula.sh")"
	if [[ -z "$extracted" ]]; then
		echo "failed to extract configure_git_push_remote from update-formula.sh" >&2
		return 1
	fi
	eval "$extracted"
	if ! type configure_git_push_remote >/dev/null 2>&1; then
		echo "configure_git_push_remote not defined after eval" >&2
		return 1
	fi
}

teardown() {
	teardown_temp_dir
}

@test "configure_git_push_remote: sets origin URL with App token" {
	cd "$TEST_TEMP_DIR"
	git init -q
	git remote add origin "https://github.com/lgtm-hq/homebrew-tap.git"

	export PUSH_TOKEN="app-installation-token"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
	configure_git_push_remote

	remote_url="$(git remote get-url origin)"
	[[ "$remote_url" == \
		"https://x-access-token:app-installation-token@github.com/lgtm-hq/homebrew-tap.git" ]]
}

@test "configure_git_push_remote: requires GITHUB_REPOSITORY when token set" {
	cd "$TEST_TEMP_DIR"
	git init -q
	git remote add origin "https://github.com/lgtm-hq/homebrew-tap.git"

	export PUSH_TOKEN="app-installation-token"
	unset GITHUB_REPOSITORY

	run configure_git_push_remote
	[ "$status" -eq 1 ]
	[[ "$output" == *"GITHUB_REPOSITORY is required"* ]]
}

@test "configure_git_push_remote: no-op when PUSH_TOKEN unset" {
	cd "$TEST_TEMP_DIR"
	git init -q
	git remote add origin "https://github.com/lgtm-hq/homebrew-tap.git"

	unset PUSH_TOKEN
	configure_git_push_remote

	remote_url="$(git remote get-url origin)"
	[[ "$remote_url" == "https://github.com/lgtm-hq/homebrew-tap.git" ]]
}
