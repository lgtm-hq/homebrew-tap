#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for update-formula.sh remote-state helper functions.

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
	# shellcheck source=../../../scripts/lib/common.sh disable=SC1091
	source "$REPO_ROOT/scripts/lib/common.sh"
	extract_function "remote_main_oid"
	extract_function "remote_file_at_ref"
	extract_function "remote_blob_sha_at_ref"
	extract_function "previous_formula_version"
	mock_gh_recording "$TEST_TEMP_DIR/mock-bin"
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
