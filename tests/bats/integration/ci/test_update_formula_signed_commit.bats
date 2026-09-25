#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Run update-formula.sh's create_signed_commit against the real,
# pinned lgtm-ci create-signed-commit.sh with only the gh CLI mocked.

load "../../../helpers/common"
load "../../../helpers/mocks"

MAIN_OID="1111111111111111111111111111111111111111"
OLD_BRANCH_OID="2222222222222222222222222222222222222222"
NEW_COMMIT_OID="c0ffeec0ffeec0ffeec0ffeec0ffeec0ffeec0ff"
BUMP_BRANCH="homebrew/lintro-1.2.3"
PR_TITLE="chore(homebrew): update lintro to 1.2.3"
TEMP_PREFIX="signed-commit-tmp/4242-1-"

# The ref update-formula.sh gets its tooling at: the default in
# scripts/ci/lib/lgtm-ci-tooling.sh, ignoring any LGTM_CI_TOOLING_REF override.
pinned_tooling_ref() {
	(
		unset LGTM_CI_TOOLING_REF
		# shellcheck source=../../../../scripts/ci/lib/lgtm-ci-tooling.sh disable=SC1091
		source "$1/scripts/ci/lib/lgtm-ci-tooling.sh"
		printf '%s\n' "$LGTM_CI_TOOLING_REF"
	)
}

# Succeeds when <dir> is an lgtm-ci checkout at <ref> with the shared script.
tooling_at_ref() {
	local dir="$1"
	local ref="$2"
	[[ -n "$dir" && -f "$dir/scripts/ci/git/create-signed-commit.sh" ]] &&
		[[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" == "$ref" ]]
}

# Resolve an lgtm-ci checkout at the pinned ref: reuse one already at that
# ref, else fetch one with scripts/ci/ensure-lgtm-ci-tooling.sh into the file
# tmpdir. In CI, .lgtm-ci-tooling is the reusable workflow's own tooling
# checkout (its tooling-ref, not the pin), so this normally fetches there.
setup_file() {
	local root ref candidate
	root="$(repo_root)"
	ref="$(pinned_tooling_ref "$root")"
	for candidate in "${LGTM_CI_TOOLING_DIR:-}" "$root/.lgtm-ci-tooling"; do
		if tooling_at_ref "$candidate" "$ref"; then
			export SIGNED_COMMIT_TOOLING_DIR="$candidate"
			return 0
		fi
	done

	candidate="$BATS_FILE_TMPDIR/lgtm-ci-tooling"
	if LGTM_CI_TOOLING_REF="$ref" \
		bash "$root/scripts/ci/ensure-lgtm-ci-tooling.sh" "$candidate" >&2 &&
		tooling_at_ref "$candidate" "$ref"; then
		export SIGNED_COMMIT_TOOLING_DIR="$candidate"
		return 0
	fi

	local reason="lgtm-ci tooling at ${ref} unavailable (fetch failed); cannot run the shared create-signed-commit.sh"
	if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
		echo "$reason" >&2
		return 1
	fi
	export SIGNED_COMMIT_SKIP_REASON="$reason"
}

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
	if [[ -n "${SIGNED_COMMIT_SKIP_REASON:-}" ]]; then
		skip "$SIGNED_COMMIT_SKIP_REASON"
	fi
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	# shellcheck source=../../../../scripts/ci/lib/common.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/common.sh"
	extract_function "signed_commit_helper"
	extract_function "create_signed_commit"

	export LGTM_CI_TOOLING_DIR="$SIGNED_COMMIT_TOOLING_DIR"
	export GITHUB_REPOSITORY="lgtm-hq/homebrew-tap"
	export GH_TOKEN="test-token"
	export GITHUB_RUN_ID="4242"
	export GITHUB_RUN_ATTEMPT="1"
	# Keep the shared script from writing outputs into a real CI job.
	unset GITHUB_OUTPUT

	export MOCK_GH_REPO="$GITHUB_REPOSITORY"
	export MOCK_COMMIT_OID="$NEW_COMMIT_OID"
	export MOCK_GH_GRAPHQL_PAYLOAD="$TEST_TEMP_DIR/graphql-payload.json"
	mock_gh_signed_commit_api "$TEST_TEMP_DIR/mock-bin"

	cd "$TEST_TEMP_DIR"
	mkdir -p Formula
	printf 'class Lintro < Formula\n  version "1.2.3"\nend\n' >Formula/lintro.rb
	printf 'class LintroFull < Formula\n  version "1.2.3"\nend\n' \
		>Formula/lintro-full.rb
}

teardown() {
	teardown_temp_dir
}

commit_bump() {
	create_signed_commit "$BUMP_BRANCH" "$MAIN_OID" "$PR_TITLE" \
		"Formula/lintro.rb" "Formula/lintro-full.rb"
}

# Asserts the GraphQL commit targets a signed-commit-tmp/* branch at MAIN_OID
# with both formula files and the PR title; prints that temp branch.
assert_commit_payload() {
	local input temp_branch
	input="$(jq -c '.variables.input' "$MOCK_GH_GRAPHQL_PAYLOAD")"
	temp_branch="$(jq -r '.branch.branchName' <<<"$input")"
	[[ "$temp_branch" == "$TEMP_PREFIX"* ]] || return 1
	[ "$(jq -r '.branch.repositoryNameWithOwner' <<<"$input")" = "$GITHUB_REPOSITORY" ] || return 1
	[ "$(jq -r '.expectedHeadOid' <<<"$input")" = "$MAIN_OID" ] || return 1
	[ "$(jq -r '.message.headline' <<<"$input")" = "$PR_TITLE" ] || return 1
	[ "$(jq -r '.fileChanges.additions | map(.path) | join(",")' <<<"$input")" = \
		"Formula/lintro.rb,Formula/lintro-full.rb" ] || return 1
	[ "$(jq -r '.fileChanges.additions[0].contents' <<<"$input" | base64 -d)" = \
		"$(cat Formula/lintro.rb)" ] || return 1
	[ "$(jq -r '.fileChanges.additions[1].contents' <<<"$input" | base64 -d)" = \
		"$(cat Formula/lintro-full.rb)" ] || return 1
	printf '%s\n' "$temp_branch"
}

@test "create_signed_commit (real helper): creates a new bump branch at the signed commit" {
	run commit_bump

	[ "$status" -eq 0 ]
	[[ "$output" == *"commit-sha=${NEW_COMMIT_OID}"* ]]
	[[ "$output" != *"unexpected gh call"* ]]
	local temp_branch
	temp_branch="$(assert_commit_payload)"
	local expected
	expected="$(printf '%s\n' \
		"create ${temp_branch} ${MAIN_OID}" \
		"create ${BUMP_BRANCH} ${NEW_COMMIT_OID}" \
		"delete ${temp_branch}")"
	[ "$(cat "$MOCK_GH_REF_EVENTS")" = "$expected" ]
	grep -qx "api repos/${GITHUB_REPOSITORY} --jq .default_branch" "$MOCK_GH_LOG"
}

@test "create_signed_commit (real helper): moves an existing bump branch to the signed commit" {
	export MOCK_EXISTING_BRANCH="$BUMP_BRANCH"
	export MOCK_EXISTING_BRANCH_OID="$OLD_BRANCH_OID"

	run commit_bump

	[ "$status" -eq 0 ]
	[[ "$output" == *"commit-sha=${NEW_COMMIT_OID}"* ]]
	[[ "$output" != *"unexpected gh call"* ]]
	local temp_branch
	temp_branch="$(assert_commit_payload)"
	local expected
	expected="$(printf '%s\n' \
		"create ${temp_branch} ${MAIN_OID}" \
		"update ${BUMP_BRANCH} ${NEW_COMMIT_OID}" \
		"delete ${temp_branch}")"
	[ "$(cat "$MOCK_GH_REF_EVENTS")" = "$expected" ]
}

@test "create_signed_commit (real helper): GraphQL error fails and leaves the bump branch untouched" {
	export MOCK_EXISTING_BRANCH="$BUMP_BRANCH"
	export MOCK_EXISTING_BRANCH_OID="$OLD_BRANCH_OID"
	export MOCK_GRAPHQL_RESPONSE='{"errors":[{"message":"expected head oid mismatch"}]}'

	run commit_bump

	[ "$status" -ne 0 ]
	[[ "$output" == *"expected head oid mismatch"* ]]
	[[ "$output" != *"unexpected gh call"* ]]
	local temp_branch
	temp_branch="$(assert_commit_payload)"
	local expected
	expected="$(printf '%s\n' \
		"create ${temp_branch} ${MAIN_OID}" \
		"delete ${temp_branch}")"
	[ "$(cat "$MOCK_GH_REF_EVENTS")" = "$expected" ]
	run grep -F " ${BUMP_BRANCH}" "$MOCK_GH_REF_EVENTS"
	[ "$status" -eq 1 ]
}

@test "create_signed_commit (real helper): refuses to reset the default branch" {
	run create_signed_commit "main" "$MAIN_OID" "$PR_TITLE" "Formula/lintro.rb"

	[ "$status" -ne 0 ]
	[[ "$output" == *"default branch"* ]]
	[ ! -s "$MOCK_GH_REF_EVENTS" ]
	[ ! -s "$MOCK_GH_GRAPHQL_PAYLOAD" ]
}
