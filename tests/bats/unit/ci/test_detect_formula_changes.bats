#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for detect-formula-changes.sh path decision logic.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	unset BASE_SHA HEAD_SHA CHANGED_FILES LGTM_CI_RUNNER EVENT_NAME PUSH_BEFORE
	REPO_ROOT="$(repo_root)"
	GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output"
	export GITHUB_OUTPUT
}

teardown() {
	teardown_temp_dir
}

@test "detect-formula-changes: formula file requires validation" {
	export CHANGED_FILES=$'Formula/lintro.rb\nREADME.md'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: script change requires validation" {
	export CHANGED_FILES='scripts/ci/generate-binary-formula.sh'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: config change requires validation" {
	export CHANGED_FILES='formulas/winnow.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: unrelated workflow change skips validation" {
	export CHANGED_FILES=$'.github/workflows/ci.yml\n.github/workflows/pr-auto-assign.yml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: docs-only change skips validation" {
	export CHANGED_FILES=$'README.md\npyproject.toml'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: empty generic runner falls back to Ubuntu" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER=''
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=ubuntu-26.04$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: no-op uses supplied generic runner" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=custom-ubuntu-runner$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: supplied runner is literal data" {
	export CHANGED_FILES='README.md'
	export LGTM_CI_RUNNER='${{ vars.UNTRUSTED }}$(exit 99)'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -Fxq "runner=$LGTM_CI_RUNNER" "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: non-formula merge-group diff skips macOS" {
	export BASE_SHA='merge-base'
	export HEAD_SHA='merge-head'
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	git() {
		[ "$*" = 'diff --name-only merge-base...merge-head' ] || return 1
		printf '%s\n' README.md
	}
	export -f git
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=false$' "$GITHUB_OUTPUT"
	grep -q '^runner=custom-ubuntu-runner$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: empty push/dispatch base defaults to macOS" {
	export BASE_SHA=""
	export LGTM_CI_RUNNER='custom-ubuntu-runner'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

@test "detect-formula-changes: unset push/dispatch base defaults to macOS" {
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	grep -q '^formula=true$' "$GITHUB_OUTPUT"
	grep -q '^runner=macos-26$' "$GITHUB_OUTPUT"
}

# =============================================================================
# Per-formula selection (#661)
# =============================================================================

output_value() {
	grep "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-
}

# Run the script for a push whose diff is the given newline-separated paths.
run_push() {
	export EVENT_NAME=push
	export CHANGED_FILES="$1"
	run bash "${2:-$REPO_ROOT}/scripts/ci/detect-formula-changes.sh"
}

assert_selected() {
	[ "$status" -eq 0 ]
	[ "$(output_value formula)" = "true" ]
	[ "$(output_value formulas)" = "$1" ]
	[ "$(output_value runner)" = "macos-26" ]
}

# Every formula: formula=true with an empty list.
assert_all() {
	assert_selected ""
	[[ "$output" == *"Validating every formula"* ]]
}

# Build a temporary git repository with two commits on one line of history.
make_git_repo() {
	GIT_REPO="$TEST_TEMP_DIR/repo"
	mkdir -p "$GIT_REPO/Formula"
	cd "$GIT_REPO"
	git init -q
	git config user.email test@example.com
	git config user.name test
	git config commit.gpgsign false
	echo a >README.md
	git add README.md
	git commit -qm first
	FIRST_SHA="$(git rev-parse HEAD)"
	echo a >Formula/winnow.rb
	git add Formula/winnow.rb
	git commit -qm second
	SECOND_SHA="$(git rev-parse HEAD)"
}

@test "detect-formula-changes: push of one formula file validates that formula" {
	run_push $'Formula/winnow.rb\nREADME.md'
	assert_selected "winnow"
	[[ "$output" == *"Validating formulas changed by this push: winnow"* ]]
}

@test "detect-formula-changes: push of lintro formula validates only lintro" {
	run_push 'Formula/lintro.rb'
	assert_selected "lintro"
}

@test "detect-formula-changes: push of a shared config validates its formulas" {
	run_push 'formulas/lintro.yml'
	assert_selected "lintro lintro-full"
}

@test "detect-formula-changes: push of config and formula validates once" {
	run_push $'formulas/winnow.yml\nFormula/winnow.rb'
	assert_selected "winnow"
}

@test "detect-formula-changes: push of two products validates both" {
	run_push $'Formula/winnow.rb\nFormula/lintro.rb'
	assert_selected "lintro winnow"
}

@test "detect-formula-changes: push of shared files validates every formula" {
	local path
	for path in \
		scripts/ci/templates/pypi-full.rb.template \
		scripts/ci/render_formula.py \
		scripts/ci/generate-pypi-formula.sh \
		scripts/ci/validate-formulas.sh \
		scripts/ci/lib/local-tap.sh \
		.github/workflows/validate-homebrew-formula.yml \
		.github/workflows/update-formula.yml; do
		: >"$GITHUB_OUTPUT"
		run_push $'Formula/winnow.rb\n'"$path"
		assert_all
	done
}

@test "detect-formula-changes: push of unrelated files validates nothing" {
	run_push $'README.md\n.github/workflows/ci.yml\npyproject.toml'
	[ "$status" -eq 0 ]
	[ "$(output_value formula)" = "false" ]
	[ "$(output_value formulas)" = "" ]
	[ "$(output_value runner)" = "ubuntu-26.04" ]
	[[ "$output" == *"No formula-related changes in this push; nothing to validate."* ]]
}

@test "detect-formula-changes: push deleting a formula validates every formula" {
	run_push 'Formula/removed-formula.rb'
	assert_all
}

@test "detect-formula-changes: push of an unknown formula-tree path validates all" {
	local path
	for path in formulas/README.md formulas/removed.yml Formula/notes.txt; do
		: >"$GITHUB_OUTPUT"
		run_push "$path"
		assert_all
	done
}

@test "detect-formula-changes: config key without a formula file validates all" {
	local tap="$TEST_TEMP_DIR/tap"
	mkdir -p "$tap/scripts/ci" "$tap/Formula" "$tap/formulas"
	cp "$REPO_ROOT/scripts/ci/detect-formula-changes.sh" "$tap/scripts/ci/"
	: >"$tap/Formula/alpha.rb"
	cat >"$tap/formulas/alpha.yml" <<'YAML'
---
package: alpha
formulas:
  alpha:
    type: pypi
  alpha-new:
    type: pypi
YAML
	run_push 'formulas/alpha.yml' "$tap"
	assert_all
}

@test "detect-formula-changes: push base all zeros validates every formula" {
	export EVENT_NAME=push
	export PUSH_BEFORE=0000000000000000000000000000000000000000
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: empty push base validates every formula" {
	export EVENT_NAME=push
	export PUSH_BEFORE=''
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: push base missing from the clone validates all" {
	make_git_repo
	export EVENT_NAME=push
	export PUSH_BEFORE=1111111111111111111111111111111111111111
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: force-push base validates every formula" {
	make_git_repo
	# Rewrite history: the old head is no longer an ancestor of HEAD.
	git reset -q --hard "$FIRST_SHA"
	echo b >README.md
	git commit -qam rewritten
	export EVENT_NAME=push
	export PUSH_BEFORE="$SECOND_SHA"
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: push diffs from its before commit" {
	make_git_repo
	export EVENT_NAME=push
	export PUSH_BEFORE="$FIRST_SHA"
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_selected "winnow"
}

@test "detect-formula-changes: push with no changes since before validates nothing" {
	make_git_repo
	export EVENT_NAME=push
	export PUSH_BEFORE="$SECOND_SHA"
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	[ "$status" -eq 0 ]
	[ "$(output_value formula)" = "false" ]
}

@test "detect-formula-changes: manual dispatch validates every formula" {
	export EVENT_NAME=workflow_dispatch
	export PUSH_BEFORE=''
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: pull request formula change validates all" {
	export EVENT_NAME=pull_request
	export CHANGED_FILES='Formula/winnow.rb'
	run bash "$REPO_ROOT/scripts/ci/detect-formula-changes.sh"
	assert_all
}

@test "detect-formula-changes: every formula source in the repo is mapped" {
	bootstrap_test_env "$REPO_ROOT"
	local path name expected formula covered=""

	# Every tracked file either selects formulas or is a known non-formula
	# path. A new kind of formula source (a new directory, a cask, a config
	# outside formulas/) fails here until the selection maps it.
	local non_formula='^(\.github/|tests/|[^/]+\.md$|LICENSE$|\.[^/]+$|pyproject\.toml$|uv\.lock$|renovate\.json$)'
	while IFS= read -r path; do
		: >"$GITHUB_OUTPUT"
		run_push "$path"
		[ "$status" -eq 0 ]
		if [ "$(output_value formula)" != "true" ]; then
			[[ "$path" =~ $non_formula ]] || {
				echo "unmapped path: $path" >&2
				return 1
			}
		fi
		if [[ "$path" =~ ^(Formula|formulas)/ ]]; then
			[ "$(output_value formula)" = "true" ]
		fi
	done < <(git -C "$REPO_ROOT" ls-files)

	# A formula file selects exactly its own formula.
	for formula in "$REPO_ROOT"/Formula/*.rb; do
		name="$(basename "$formula" .rb)"
		: >"$GITHUB_OUTPUT"
		run_push "Formula/$name.rb"
		assert_selected "$name"
	done

	# A config selects exactly the formulas its YAML defines, and together the
	# configs cover every formula file.
	for path in "$REPO_ROOT"/formulas/*.yml; do
		expected="$(python3 "$REPO_ROOT/scripts/ci/read_formula_config.py" \
			"$path" --list-formulas | LC_ALL=C sort | tr '\n' ' ')"
		: >"$GITHUB_OUTPUT"
		run_push "formulas/$(basename "$path")"
		assert_selected "${expected% }"
		covered="$covered ${expected}"
	done
	for formula in "$REPO_ROOT"/Formula/*.rb; do
		name="$(basename "$formula" .rb)"
		[[ " $covered " == *" $name "* ]]
	done
}
