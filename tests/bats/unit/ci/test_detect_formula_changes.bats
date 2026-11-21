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
		[ "$*" = '-c core.quotePath=false diff --name-only --no-renames merge-base...merge-head' ] || return 1
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
		scripts/ci/lib/config-formula-keys.awk \
		.gitattributes \
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
	mkdir -p "$tap/scripts/ci/lib" "$tap/Formula" "$tap/formulas"
	cp "$REPO_ROOT/scripts/ci/detect-formula-changes.sh" "$tap/scripts/ci/"
	cp "$REPO_ROOT/scripts/ci/lib/config-formula-keys.awk" "$tap/scripts/ci/lib/"
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
	# outside formulas/), a new action or reusable workflow, or a new dotfile
	# fails here until the selection maps it or this list names it.
	# pyproject.toml and uv.lock feed only the generator; validation checks
	# the committed formula files and calls no Python.
	local non_formula='^(tests/|[^/]+\.md$|LICENSE$|pyproject\.toml$|uv\.lock$|renovate\.json$'
	non_formula+='|\.github/(CODEOWNERS|PULL_REQUEST_TEMPLATE\.md|actionlint\.yaml)$'
	non_formula+='|\.github/workflows/(ai-review|all-checks-gate|ci|deploy-pages|merge-release-bot-pr|pr-auto-assign|scheduled-validation)\.yml$'
	non_formula+='|\.(gitignore|lintro-config\.yaml|lintro-ignore|markdownlint-cli2\.jsonc|prettierignore|prettierrc\.json|shellcheckrc|typos\.toml|yamllint)$)'
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

# =============================================================================
# Real git history: renames, quoted names, several commits, merges
# =============================================================================

# Build a temporary tap repository with the real selection script, formulas
# and configs, so REPO_ROOT inside the script is the temporary repository.
make_tap_repo() {
	GIT_REPO="$TEST_TEMP_DIR/tap-repo"
	mkdir -p "$GIT_REPO/scripts/ci/lib" "$GIT_REPO/Formula" "$GIT_REPO/formulas"
	cp "$REPO_ROOT/scripts/ci/detect-formula-changes.sh" "$GIT_REPO/scripts/ci/"
	cp "$REPO_ROOT/scripts/ci/lib/config-formula-keys.awk" "$GIT_REPO/scripts/ci/lib/"
	cp "$REPO_ROOT"/Formula/*.rb "$GIT_REPO/Formula/"
	cp "$REPO_ROOT"/formulas/*.yml "$GIT_REPO/formulas/"
	echo helper >"$GIT_REPO/scripts/ci/helper.sh"
	echo readme >"$GIT_REPO/README.md"
	cd "$GIT_REPO"
	git init -q
	git checkout -qb main
	git config user.email test@example.com
	git config user.name test
	git config commit.gpgsign false
	git add -A
	git commit -qm base
	BASE_COMMIT="$(git rev-parse HEAD)"
}

# Run the temporary repository's script for a push from the given commit.
run_tap_push() {
	export EVENT_NAME=push
	export PUSH_BEFORE="$1"
	run bash "$GIT_REPO/scripts/ci/detect-formula-changes.sh"
}

# Run the temporary repository's script for a pull request from BASE_COMMIT.
run_tap_pull_request() {
	export EVENT_NAME=pull_request
	export BASE_SHA="$BASE_COMMIT"
	HEAD_SHA="$(git rev-parse HEAD)"
	export HEAD_SHA
	run bash "$GIT_REPO/scripts/ci/detect-formula-changes.sh"
}

@test "detect-formula-changes: moving a formula out of Formula/ validates all" {
	make_tap_repo
	mkdir attic
	git mv Formula/winnow.rb attic/winnow.rb
	git commit -qm move
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: moving a script out of scripts/ validates all" {
	make_tap_repo
	mkdir tools
	git mv scripts/ci/helper.sh tools/helper.sh
	git commit -qm move
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: moving a config out of formulas/ validates all" {
	make_tap_repo
	mkdir docs
	git mv formulas/winnow.yml docs/winnow.yml
	git commit -qm move
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: renaming a formula inside Formula/ validates all" {
	make_tap_repo
	git mv Formula/winnow.rb Formula/winnow-next.rb
	git commit -qm rename
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: pull request moving a formula out validates all" {
	make_tap_repo
	mkdir attic
	git mv Formula/winnow.rb attic/winnow.rb
	git commit -qm move
	run_tap_pull_request
	assert_all
}

@test "detect-formula-changes: non-ASCII formula path validates all" {
	make_tap_repo
	echo x >"Formula/caf$(printf '\303\251').rb"
	git add -A
	git commit -qm accent
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: path git still quotes validates all" {
	make_tap_repo
	echo x >'Formula/a"b.rb'
	git add -A
	git commit -qm quote
	# Even with core.quotePath=false git quotes this name.
	[[ "$(git -c core.quotePath=false diff --name-only "$BASE_COMMIT" HEAD)" == \"* ]]
	run_tap_push "$BASE_COMMIT"
	assert_all
}

@test "detect-formula-changes: pull request with a non-ASCII path validates all" {
	make_tap_repo
	echo x >"scripts/caf$(printf '\303\251').sh"
	git add -A
	git commit -qm accent
	run_tap_pull_request
	assert_all
}

@test "detect-formula-changes: pull request with a quoted path validates all" {
	make_tap_repo
	echo x >'notes "draft".txt'
	git add -A
	git commit -qm quote
	run_tap_pull_request
	assert_all
}

@test "detect-formula-changes: push of several commits validates every package" {
	make_tap_repo
	echo '# change' >>Formula/winnow.rb
	git commit -qam winnow
	echo '# change' >>formulas/lintro.yml
	git commit -qam lintro
	echo more >>README.md
	git commit -qam docs
	run_tap_push "$BASE_COMMIT"
	assert_selected "lintro lintro-full winnow"
}

@test "detect-formula-changes: push of a merge commit validates the merged change" {
	make_tap_repo
	git checkout -qb side
	echo '# change' >>Formula/lintro.rb
	git commit -qam lintro
	git checkout -q main
	echo '# change' >>Formula/winnow.rb
	git commit -qam winnow
	local winnow_commit
	winnow_commit="$(git rev-parse HEAD)"
	git merge -q --no-ff -m merge side

	# The push carries the winnow commit and the merge.
	run_tap_push "$BASE_COMMIT"
	assert_selected "lintro winnow"

	# winnow was already pushed; the push carries only the merge.
	: >"$GITHUB_OUTPUT"
	run_tap_push "$winnow_commit"
	assert_selected "lintro"
}

@test "detect-formula-changes: config the awk reader rejects validates all" {
	make_tap_repo
	printf 'formulas:\n  lintro: {}\n  ? lintro-full\n  : {}\n' >formulas/lintro.yml
	git commit -qam explicit-key
	run_tap_push "$BASE_COMMIT"
	assert_all
}

# =============================================================================
# config-formula-keys.awk
# =============================================================================

AWK_READER_REL="scripts/ci/lib/config-formula-keys.awk"

# Print every awk implementation installed here, one command per line.
available_awks() {
	local impl
	for impl in awk gawk mawk; do
		if command -v "$impl" >/dev/null 2>&1; then
			echo "$impl"
		fi
	done
	if command -v busybox >/dev/null 2>&1 &&
		busybox awk 'BEGIN { exit 0 }' >/dev/null 2>&1; then
		echo "busybox awk"
	fi
	return 0
}

# Read a config with one awk implementation; prints the sorted keys, or ALL
# when the reader rejects the layout or finds no key.
read_keys_with() {
	local impl="$1" file="$2" keys
	local -a cmd
	read -r -a cmd <<<"$impl"
	if ! keys="$("${cmd[@]}" -f "$REPO_ROOT/$AWK_READER_REL" "$file")" ||
		[ -z "$keys" ]; then
		echo ALL
		return 0
	fi
	printf '%s\n' "$keys" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}

# Assert every installed awk reads the config text in $1 as $2.
assert_awk_reads() {
	local file="$TEST_TEMP_DIR/config.yml" impl actual
	printf '%s' "$1" >"$file"
	while IFS= read -r impl; do
		actual="$(read_keys_with "$impl" "$file")"
		[ "$actual" = "$2" ] || {
			echo "$impl read '$actual', expected '$2' from:" >&2
			cat -A "$file" >&2 2>/dev/null || cat "$file" >&2
			return 1
		}
	done < <(available_awks)
}

@test "config-formula-keys: reports which awk implementations ran" {
	local impls
	impls="$(available_awks | tr '\n' ',' | sed 's/,$//')"
	[ -n "$impls" ]
	echo "# config-formula-keys.awk tested with: $impls" >&3
}

@test "config-formula-keys: reads the plain layout" {
	assert_awk_reads $'---\npackage: alpha\nformulas:\n  # comment\n  alpha:\n    type: pypi\n\n  alpha-full:\n    extras:\n      - mcp\nother: 1\n' \
		"alpha alpha-full"
	assert_awk_reads $'formulas:\n    alpha: {}\n    beta:\n      test: |\n        beta-2:\n        "x\n' \
		"alpha beta"
}

@test "config-formula-keys: reads the committed configs" {
	local path impl
	for path in "$REPO_ROOT"/formulas/*.yml; do
		while IFS= read -r impl; do
			[ "$(read_keys_with "$impl" "$path")" != ALL ]
		done < <(available_awks)
	done
}

@test "config-formula-keys: explicit-key mapping falls back to all" {
	assert_awk_reads $'formulas:\n  lintro: {}\n  ? lintro-full\n  : {}\n' ALL
}

@test "config-formula-keys: key line without a colon falls back to all" {
	assert_awk_reads $'formulas:\n  lintro: {}\n  lintro-full\n    : {}\n' ALL
	assert_awk_reads $'formulas:\n  lintro: {}\n  lintro-full\n  : {}\n' ALL
}

@test "config-formula-keys: tab indentation falls back to all" {
	assert_awk_reads $'formulas:\n  lintro: {}\n\tlintro-full: {}\n' ALL
	assert_awk_reads $'formulas:\n\tlintro: {}\n' ALL
	assert_awk_reads $'formulas:\n  lintro:\n  \ttype: pypi\n' ALL
}

@test "config-formula-keys: multi-document file falls back to all" {
	assert_awk_reads $'---\nformulas:\n  lintro: {}\n---\nformulas:\n  winnow: {}\n' ALL
	assert_awk_reads $'formulas:\n  lintro: {}\n...\n' ALL
	assert_awk_reads $'%YAML 1.1\n---\nformulas:\n  lintro: {}\n' ALL
}

@test "config-formula-keys: other unsupported layouts fall back to all" {
	local text
	for text in \
		$'formulas: {lintro: {}}\n' \
		$'formulas: !!omap\n  - lintro: {}\n' \
		$'formulas: &f\n  lintro: {}\n' \
		$'formulas:\n  - lintro\n' \
		$'formulas:\n  "lintro": {}\n' \
		$'formulas:\n  lintro :\n' \
		$'formulas:\n  true: {}\n' \
		$'formulas:\n  010: {}\n' \
		$'formulas:\n  lintro: {}\n winnow: {}\n' \
		$'formulas:\n  lintro: {}\nformulas:\n  winnow: {}\n' \
		$'formulas:\n  lintro:\n    desc: "one\n  winnow: two"\n' \
		$'formulas:\n  lintro:\n    extras: [a,\n  winnow: b]\n' \
		$'formulas:\n  lintro: {}\n  <<: {winnow: {}}\n' \
		$'formulas:\r\n  lintro: {}\r\n' \
		$'"formulas":\n  lintro: {}\n' \
		$'formulas:\n' \
		$'package: x\n'; do
		assert_awk_reads "$text" ALL
	done
}

@test "config-formula-keys: matches read_formula_config.py or falls back to all" {
	ensure_test_python_deps "$REPO_ROOT"
	local cases="$TEST_TEMP_DIR/cases" manifest="$TEST_TEMP_DIR/manifest.tsv"
	local file plain expected impl actual exact=0 fallback=0 failures=0
	mkdir -p "$cases"
	python3 "$REPO_ROOT/tests/helpers/awk_reader_property.py" \
		"$REPO_ROOT/scripts/ci/read_formula_config.py" "$cases" >"$manifest"
	[ "$(wc -l <"$manifest")" -ge 500 ]

	# Same set as Python, or every formula; a plain layout must match exactly,
	# and a file Python rejects must fall back to every formula.
	while IFS=$'\t' read -r file plain expected; do
		while IFS= read -r impl; do
			actual="$(read_keys_with "$impl" "$cases/$file")"
			if [ "$actual" = ALL ] && [ "$plain" = 0 ]; then
				fallback=$((fallback + 1))
			elif [ "$actual" != ALL ] && [ "$actual" = "$expected" ]; then
				exact=$((exact + 1))
			else
				failures=$((failures + 1))
				echo "$file [$impl]: awk '$actual', python '$expected'" >&2
			fi
		done < <(available_awks)
	done <"$manifest"
	echo "# awk reader: $exact exact, $fallback fell back to all, $failures failures" >&3
	[ "$failures" -eq 0 ]
	[ "$exact" -gt 0 ]
}

@test "config-formula-keys: a config without formula keys exits 2" {
	local file="$TEST_TEMP_DIR/config.yml" impl text status
	local -a cmd
	for text in "" $'other: 1\n' $'formulas:\n' $'formulas:\n- lintro\n' \
		$'formulas: null\n' $'# only a comment\n'; do
		printf '%s' "$text" >"$file"
		while IFS= read -r impl; do
			read -r -a cmd <<<"$impl"
			status=0
			"${cmd[@]}" -f "$REPO_ROOT/$AWK_READER_REL" "$file" >/dev/null || status=$?
			[ "$status" -eq 2 ] || {
				echo "$impl exited $status, expected 2, for: $text" >&2
				return 1
			}
		done < <(available_awks)
	done
}
