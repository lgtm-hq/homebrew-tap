#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for update-formula.sh remote-state and signed-commit helpers.

load "../../../helpers/common"
load "../../../helpers/mocks"

extract_function() {
	local name="$1"
	local extracted
	extracted="$(sed -n "/^${name}() {/,/^}/p" \
		"$REPO_ROOT/scripts/ci/update-formula.sh")"
	if [[ -z "$extracted" ]]; then
		echo "failed to extract ${name} from update-formula.sh" >&2
		return 1
	fi
	eval "$extracted"
	type "$name" >/dev/null 2>&1
}

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	# shellcheck source=../../../../scripts/ci/lib/common.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/common.sh"
	extract_function "remote_main_oid"
	extract_function "remote_file_at_ref"
	extract_function "remote_blob_sha_at_ref"
	extract_function "previous_formula_version"
	extract_function "signed_commit_helper"
	extract_function "create_signed_commit"
	mock_gh_recording "$TEST_TEMP_DIR/mock-bin"
	mock_signed_commit_helper "$TEST_TEMP_DIR/lgtm-ci-tooling"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
}

teardown() {
	teardown_temp_dir
}

@test "remote_main_oid: returns current main head sha" {
	export MOCK_MAIN_OID="abc123abc123abc123abc123abc123abc123abc1"

	run remote_main_oid
	[ "$status" -eq 0 ]
	[ "$output" = "abc123abc123abc123abc123abc123abc123abc1" ]
}

@test "remote_file_at_ref: returns file content at ref" {
	export MOCK_REMOTE_FILE="$TEST_TEMP_DIR/remote-formula.rb"
	printf 'class LintroFull < Formula\nend\n' >"$MOCK_REMOTE_FILE"

	run remote_file_at_ref "Formula/lintro-full.rb" "abc123"
	[ "$status" -eq 0 ]
	[[ "$output" == *"class LintroFull < Formula"* ]]
}

@test "remote_file_at_ref: empty output for missing file" {
	unset MOCK_REMOTE_FILE

	run remote_file_at_ref "Formula/nope.rb" "abc123"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "remote_file_at_ref: fails loudly on non-404 API errors" {
	export MOCK_CONTENTS_ERROR="gh: You have exceeded a secondary rate limit (HTTP 403)"

	run remote_file_at_ref "Formula/lintro.rb" "abc123"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch Formula/lintro.rb@abc123"* ]]
}

@test "remote_blob_sha_at_ref: fails loudly on non-404 API errors" {
	export MOCK_CONTENTS_ERROR="gh: You have exceeded a secondary rate limit (HTTP 403)"

	run remote_blob_sha_at_ref "Formula/lintro.rb" "abc123"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to fetch blob sha for Formula/lintro.rb@abc123"* ]]
}

@test "remote_blob_sha_at_ref: returns blob sha and empty on 404" {
	export MOCK_REMOTE_BLOB_SHA="feedfacefeedfacefeedfacefeedfacefeedface"
	run remote_blob_sha_at_ref "Formula/lintro.rb" "abc123"
	[ "$status" -eq 0 ]
	[ "$output" = "feedfacefeedfacefeedfacefeedfacefeedface" ]

	unset MOCK_REMOTE_BLOB_SHA
	run remote_blob_sha_at_ref "Formula/nope.rb" "abc123"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "previous_formula_version: parses sdist version from url stanza" {
	previous_formula_version <<'EOF' >"$TEST_TEMP_DIR/version.txt"
class LintroFull < Formula
  url "https://files.pythonhosted.org/packages/ab/cd/lintro-0.77.0.tar.gz"
  sha256 "abc"
end
EOF

	[ "$(cat "$TEST_TEMP_DIR/version.txt")" = "0.77.0" ]
}

@test "previous_formula_version: empty for binary formulas without sdist url" {
	previous_formula_version <<'EOF' >"$TEST_TEMP_DIR/version.txt"
class Lintro < Formula
  version "0.77.0"
  url "https://github.com/lgtm-hq/py-lintro/releases/download/v0.77.0/lintro-macos-arm64"
end
EOF

	[ -z "$(cat "$TEST_TEMP_DIR/version.txt")" ]
}

# =============================================================================
# resolve_binary_assets
# =============================================================================

@test "resolve_binary_assets: passes dispatch JSON through unmodified" {
	extract_function "resolve_binary_assets"
	export DISPATCH_BINARY_ASSETS='{"arm64-sha":"aaa","x86-sha":"bbb"}'

	run resolve_binary_assets

	[ "$status" -eq 0 ]
	[ "$output" = '{"arm64-sha":"aaa","x86-sha":"bbb"}' ]
	# Regression: ${VAR:-{}} appended a literal `}` when the var was set.
	echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "resolve_binary_assets: passes an arm64-only payload through unmodified" {
	extract_function "resolve_binary_assets"
	export DISPATCH_BINARY_ASSETS='{"arm64-sha":"aaa"}'

	run resolve_binary_assets

	[ "$status" -eq 0 ]
	[ "$output" = '{"arm64-sha":"aaa"}' ]
}

@test "resolve_binary_assets: defaults to empty object when unset" {
	extract_function "resolve_binary_assets"
	unset DISPATCH_BINARY_ASSETS

	run resolve_binary_assets

	[ "$status" -eq 0 ]
	[ "$output" = '{}' ]
}

# =============================================================================
# signed_commit_helper / create_signed_commit (lgtm-ci shared script)
# =============================================================================

@test "signed_commit_helper: prints the shared script path in the tooling dir" {
	run signed_commit_helper

	[ "$status" -eq 0 ]
	[ "$output" = "$TEST_TEMP_DIR/lgtm-ci-tooling/scripts/ci/git/create-signed-commit.sh" ]
}

@test "signed_commit_helper: fails clearly when LGTM_CI_TOOLING_DIR is unset" {
	unset LGTM_CI_TOOLING_DIR

	run signed_commit_helper

	[ "$status" -eq 1 ]
	[[ "$output" == *"LGTM_CI_TOOLING_DIR is required"* ]]
}

@test "signed_commit_helper: fails clearly when the shared script is missing" {
	export LGTM_CI_TOOLING_DIR="$TEST_TEMP_DIR/old-tooling"
	mkdir -p "$LGTM_CI_TOOLING_DIR/scripts/ci"

	run signed_commit_helper

	[ "$status" -eq 1 ]
	[[ "$output" == *"Shared signed-commit script not found: $TEST_TEMP_DIR/old-tooling/scripts/ci/git/create-signed-commit.sh"* ]]
}

@test "create_signed_commit: calls the shared script in reset mode on main head" {
	local main_oid="abc123abc123abc123abc123abc123abc123abc1"

	run create_signed_commit "homebrew/lintro-1.2.3" "$main_oid" \
		"chore(homebrew): update lintro to 1.2.3" \
		"Formula/lintro.rb" "Formula/lintro-full.rb"

	[ "$status" -eq 0 ]
	[[ "$output" == *"commit-sha=c0ffee"* ]]
	local expected
	expected="$(printf '%s\n' \
		--mode reset \
		--base "$main_oid" \
		--branch "homebrew/lintro-1.2.3" \
		--message "chore(homebrew): update lintro to 1.2.3" \
		--repository "lgtm-hq/homebrew-tap" \
		--file "Formula/lintro.rb" \
		--file "Formula/lintro-full.rb")"
	[ "$(cat "$MOCK_SIGNED_COMMIT_ARGS")" = "$expected" ]
}

@test "create_signed_commit: propagates shared script failures" {
	export MOCK_SIGNED_COMMIT_FAIL="createCommitOnBranch returned no commit: boom"

	run create_signed_commit "homebrew/lintro-1.2.3" \
		"abc123abc123abc123abc123abc123abc123abc1" \
		"chore(homebrew): update lintro to 1.2.3" "Formula/lintro.rb"

	[ "$status" -ne 0 ]
	[[ "$output" == *"createCommitOnBranch returned no commit: boom"* ]]
}

@test "create_signed_commit: does not run anything without the tooling dir" {
	unset LGTM_CI_TOOLING_DIR

	run create_signed_commit "homebrew/lintro-1.2.3" \
		"abc123abc123abc123abc123abc123abc123abc1" \
		"chore(homebrew): update lintro to 1.2.3" "Formula/lintro.rb"

	[ "$status" -eq 1 ]
	[[ "$output" == *"LGTM_CI_TOOLING_DIR is required"* ]]
	[ ! -s "$MOCK_SIGNED_COMMIT_ARGS" ]
}

@test "update-formula: fails before PyPI wait when the tooling dir is unset" {
	unset LGTM_CI_TOOLING_DIR

	run env DISPATCH_FORMULA=lintro DISPATCH_VERSION=1.2.3 \
		bash "$REPO_ROOT/scripts/ci/update-formula.sh"

	[ "$status" -eq 1 ]
	[[ "$output" == *"LGTM_CI_TOOLING_DIR is required"* ]]
	[[ "$output" != *"Waiting for PyPI"* ]]
	[ ! -s "$MOCK_GH_LOG" ]
}

@test "lgtm-ci tooling ref is the same in the local fallback and both workflows" {
	local root ref wf
	root="$(repo_root)"
	# The fallback default in lgtm-ci-tooling.sh is what local runs and the
	# signed-commit integration test use; it must match what CI checks out.
	ref="$(
		unset LGTM_CI_TOOLING_REF
		# shellcheck source=/dev/null
		source "$root/scripts/ci/lib/lgtm-ci-tooling.sh"
		printf '%s' "$LGTM_CI_TOOLING_REF"
	)"
	[[ "$ref" =~ ^[0-9a-f]{40}$ ]]
	for wf in update-formula deploy-pages; do
		run grep -E "^[[:space:]]+LGTM_CI_TOOLING_REF: ${ref}([[:space:]]|$)" \
			"$root/.github/workflows/${wf}.yml"
		assert_success
	done
}

