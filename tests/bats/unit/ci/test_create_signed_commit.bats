#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for create-signed-commit.sh GraphQL commit creation.

load "../../../helpers/common"
load "../../../helpers/mocks"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	SCRIPT="$REPO_ROOT/scripts/ci/create-signed-commit.sh"
	mock_gh_recording "$TEST_TEMP_DIR/mock-bin"
	export MOCK_GH_GRAPHQL_PAYLOAD="$TEST_TEMP_DIR/graphql-payload.json"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
	export GH_TOKEN="test-token"

	cd "$TEST_TEMP_DIR"
	mkdir -p Formula
	printf 'class Lintro < Formula\n  version "1.2.3"\nend\n' \
		>Formula/lintro.rb
}

teardown() {
	teardown_temp_dir
}

@test "create-signed-commit: sends branch, expectedHeadOid, and base64 contents" {
	run bash "$SCRIPT" \
		--branch "homebrew/lintro-1.2.3" \
		--base-oid "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		--message "chore(homebrew): update lintro to 1.2.3" \
		--file "Formula/lintro.rb"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Created signed commit c0ffee"* ]]

	input="$(jq -c '.variables.input' "$MOCK_GH_GRAPHQL_PAYLOAD")"
	[ "$(jq -r '.branch.branchName' <<<"$input")" = "homebrew/lintro-1.2.3" ]
	[ "$(jq -r '.branch.repositoryNameWithOwner' <<<"$input")" = \
		"lgtm-hq/homebrew-tap" ]
	[ "$(jq -r '.expectedHeadOid' <<<"$input")" = \
		"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]
	[ "$(jq -r '.message.headline' <<<"$input")" = \
		"chore(homebrew): update lintro to 1.2.3" ]
	[ "$(jq -r '.fileChanges.additions[0].path' <<<"$input")" = \
		"Formula/lintro.rb" ]

	decoded="$(jq -r '.fileChanges.additions[0].contents' <<<"$input" | base64 -d)"
	[ "$decoded" = "$(cat Formula/lintro.rb)" ]
}

@test "create-signed-commit: creates branch ref at base oid" {
	run bash "$SCRIPT" \
		--branch "homebrew/lintro-1.2.3" \
		--base-oid "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		--message "msg" \
		--file "Formula/lintro.rb"

	[ "$status" -eq 0 ]
	grep -q \
		"api repos/lgtm-hq/homebrew-tap/git/refs -f ref=refs/heads/homebrew/lintro-1.2.3 -f sha=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		"$MOCK_GH_LOG"
}

@test "create-signed-commit: force-resets branch when ref already exists" {
	export MOCK_REF_EXISTS="true"

	run bash "$SCRIPT" \
		--branch "homebrew/lintro-1.2.3" \
		--base-oid "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		--message "msg" \
		--file "Formula/lintro.rb"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Reset existing branch homebrew/lintro-1.2.3"* ]]
	grep -q \
		"api -X PATCH repos/lgtm-hq/homebrew-tap/git/refs/heads/homebrew/lintro-1.2.3 -f sha=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef -F force=true" \
		"$MOCK_GH_LOG"
}

@test "create-signed-commit: fails loudly on GraphQL errors" {
	export MOCK_GRAPHQL_RESPONSE='{"errors":[{"message":"expected head oid mismatch"}]}'

	run bash "$SCRIPT" \
		--branch "homebrew/lintro-1.2.3" \
		--base-oid "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		--message "msg" \
		--file "Formula/lintro.rb"

	[ "$status" -eq 1 ]
	[[ "$output" == *"createCommitOnBranch failed"* ]]
	[[ "$output" == *"expected head oid mismatch"* ]]
}

@test "create-signed-commit: rejects missing arguments" {
	run bash "$SCRIPT" --branch "homebrew/lintro-1.2.3"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Missing required arguments"* ]]
}

@test "create-signed-commit: rejects missing file" {
	run bash "$SCRIPT" \
		--branch "homebrew/lintro-1.2.3" \
		--base-oid "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
		--message "msg" \
		--file "Formula/missing.rb"

	[ "$status" -eq 1 ]
	[[ "$output" == *"File not found: Formula/missing.rb"* ]]
}
