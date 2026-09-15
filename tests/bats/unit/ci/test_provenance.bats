#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for scripts/ci/lib/provenance.sh (attestation, release
# digest and sdist triple-digest checks) with a stubbed gh.

load "../../../helpers/common"
load "../../../helpers/mocks"

SDIST_SHA="846f7278e1ed929233c9de42a039eb42eb3a633f19517c7b65ed25f4a4ebe343"
OTHER_SHA="0000000000000000000000000000000000000000000000000000000000000000"
REPO="lgtm-hq/winnow"
BINARY_WF="lgtm-hq/winnow/.github/workflows/build-binaries.yml"
SDIST_WF="lgtm-hq/lgtm-ci/.github/workflows/reusable-build-python-dist.yml"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	# shellcheck source=../../../../scripts/ci/lib/common.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/common.sh"
	# shellcheck source=../../../../scripts/ci/lib/provenance.sh disable=SC1091
	source "$REPO_ROOT/scripts/ci/lib/provenance.sh"
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	SDIST="$TEST_TEMP_DIR/winnow_media-0.0.1.tar.gz"
	cp "$REPO_ROOT/tests/fixtures/sdist/winnow-media-0.0.1.tar.gz" "$SDIST"
	ASSET="$TEST_TEMP_DIR/winnow-macos-arm64"
	printf 'binary\n' >"$ASSET"
}

teardown() {
	teardown_temp_dir
}

provenance_json() { # $1 = require-attestation
	printf '{"require-attestation": %s, "repo": "%s", "tag-prefix": "v", "binary-signer-workflow": "%s", "sdist-signer-workflow": "%s", "pypi-publisher-workflow": "publish-pypi-on-tag.yml"}' \
		"$1" "$REPO" "$BINARY_WF" "$SDIST_WF"
}

# =============================================================================
# provenance_mode
# =============================================================================

@test "provenance_mode: empty block prints skip" {
	run provenance_mode '{}' binary winnow
	[ "$status" -eq 0 ]
	[ "$output" = "skip" ]
}

@test "provenance_mode: complete block prints verify" {
	run provenance_mode "$(provenance_json true)" binary winnow
	[ "$status" -eq 0 ]
	[ "$output" = "verify" ]
}

@test "provenance_mode: pypi kind does not need binary-signer-workflow" {
	local json
	json="$(provenance_json false | sed 's|"binary-signer-workflow": "[^"]*", ||')"
	run provenance_mode "$json" pypi winnow
	[ "$status" -eq 0 ]
	[ "$output" = "verify" ]
	run provenance_mode "$json" binary winnow
	[ "$status" -eq 1 ]
	[[ "$output" == *"provenance.binary-signer-workflow is required for winnow"* ]]
}

@test "provenance_mode: incomplete block fails naming every missing key" {
	run provenance_mode '{"require-attestation": false, "repo": "lgtm-hq/winnow"}' binary winnow
	[ "$status" -eq 1 ]
	[[ "$output" == *"provenance.tag-prefix is required"* ]]
	[[ "$output" == *"provenance.sdist-signer-workflow is required"* ]]
	[[ "$output" == *"provenance.pypi-publisher-workflow is required"* ]]
	[[ "$output" == *"provenance.binary-signer-workflow is required"* ]]
	[[ "$output" != *"skip"* ]]
}

@test "provenance_mode: require-attestation alone is an incomplete block, not a skip" {
	run provenance_mode '{"require-attestation": true}' pypi winnow
	[ "$status" -eq 1 ]
	[[ "$output" == *"provenance.repo is required for winnow"* ]]
}

# =============================================================================
# verify_attestation
# =============================================================================

@test "verify_attestation: passes with the configured identity" {
	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "$BINARY_WF" true

	[ "$status" -eq 0 ]
	[[ "$output" == *"Attestation verified for winnow-macos-arm64 (repo ${REPO}, signer workflow ${BINARY_WF})"* ]]
	grep -q "^attestation verify ${ASSET} --repo ${REPO} --signer-workflow ${BINARY_WF}$" "$MOCK_GH_LOG"
}

@test "verify_attestation: never passes --signer-repo (gh rejects it with --signer-workflow)" {
	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "$BINARY_WF" true

	[ "$status" -eq 0 ]
	! grep -q -- "--signer-repo" "$MOCK_GH_LOG"
}

@test "verify_attestation: identity mismatch fails when required, naming asset and identity" {
	export MOCK_GH_ATTEST_MODE=fail

	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "$BINARY_WF" true

	[ "$status" -eq 1 ]
	[[ "$output" == *"Attestation verification failed for winnow-macos-arm64"* ]]
	[[ "$output" == *"sha256 $(shasum -a 256 "$ASSET" | cut -d' ' -f1)"* ]]
	[[ "$output" == *"no attestation from repo ${REPO}, signer workflow ${BINARY_WF} matched"* ]]
	[[ "$output" == *'verifying with issuer "sigstore.dev"'* ]]
}

@test "verify_attestation: missing attestation (404) fails when required" {
	export MOCK_GH_ATTEST_MODE=missing

	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "$BINARY_WF" true

	[ "$status" -eq 1 ]
	[[ "$output" == *"Attestation verification failed for winnow-macos-arm64"* ]]
	[[ "$output" == *"no attestations found"* ]]
}

@test "verify_attestation: failure only warns when require-attestation is false" {
	export MOCK_GH_ATTEST_MODE=missing

	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "$BINARY_WF" false

	[ "$status" -eq 0 ]
	[[ "$output" == *"[WARN]"* ]]
	[[ "$output" == *"require-attestation is false, continuing"* ]]
}

@test "verify_attestation: unconfigured identity is an error even when not required" {
	run verify_attestation "$ASSET" winnow-macos-arm64 "" "" false

	[ "$status" -eq 1 ]
	[[ "$output" == *"No attestation identity (repo + signer workflow) configured for winnow-macos-arm64"* ]]
	[ ! -s "$MOCK_GH_LOG" ]

	run verify_attestation "$ASSET" winnow-macos-arm64 "$REPO" "" true
	[ "$status" -eq 1 ]
	[ ! -s "$MOCK_GH_LOG" ]
}

# =============================================================================
# release_asset_digest / check_sdist_digests
# =============================================================================

@test "release_asset_digest: strips the sha256: prefix from the API digest" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"

	run release_asset_digest "$REPO" v0.0.1 winnow_media-0.0.1.tar.gz

	[ "$status" -eq 0 ]
	[ "$output" = "$SDIST_SHA" ]
	grep -q "^api repos/${REPO}/releases/tags/v0.0.1 --jq" "$MOCK_GH_LOG"
}

@test "release_asset_digest: fails when the asset has no digest" {
	unset MOCK_RELEASE_DIGEST

	run release_asset_digest "$REPO" v0.0.1 winnow_media-0.0.1.tar.gz

	[ "$status" -eq 1 ]
	[[ "$output" == *"has no sha256 digest for asset winnow_media-0.0.1.tar.gz"* ]]
}

@test "release_asset_digest: fails loudly on API errors" {
	export MOCK_RELEASE_API_ERROR="gh: Not Found (HTTP 404)"

	run release_asset_digest "$REPO" v0.0.1 winnow_media-0.0.1.tar.gz

	[ "$status" -eq 1 ]
	[[ "$output" == *"Failed to read release v0.0.1 of ${REPO}"* ]]
}

@test "check_sdist_digests: three equal digests pass" {
	run check_sdist_digests f.tar.gz "$SDIST_SHA" "$SDIST_SHA" "$SDIST_SHA"

	[ "$status" -eq 0 ]
	[[ "$output" == *"PyPI JSON == downloaded == GitHub Release"* ]]
}

@test "check_sdist_digests: PyPI digest mismatch fails naming all three" {
	run check_sdist_digests f.tar.gz "$OTHER_SHA" "$SDIST_SHA" "$SDIST_SHA"

	[ "$status" -eq 1 ]
	[[ "$output" == *"sdist digest mismatch for f.tar.gz"* ]]
	[[ "$output" == *"PyPI JSON:       ${OTHER_SHA}"* ]]
	[[ "$output" == *"downloaded file: ${SDIST_SHA}"* ]]
	[[ "$output" == *"GitHub Release:  ${SDIST_SHA}"* ]]
}

@test "check_sdist_digests: downloaded digest mismatch fails" {
	run check_sdist_digests f.tar.gz "$SDIST_SHA" "$OTHER_SHA" "$SDIST_SHA"

	[ "$status" -eq 1 ]
	[[ "$output" == *"downloaded file: ${OTHER_SHA}"* ]]
}

@test "check_sdist_digests: release digest mismatch fails" {
	run check_sdist_digests f.tar.gz "$SDIST_SHA" "$SDIST_SHA" "$OTHER_SHA"

	[ "$status" -eq 1 ]
	[[ "$output" == *"GitHub Release:  ${OTHER_SHA}"* ]]
}

# =============================================================================
# verify_sdist_provenance (release digest + PEP 740 + attestation)
# =============================================================================

@test "verify_sdist_provenance: all three digests, PEP 740 and attestation agree" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" "$(provenance_json true)"

	[ "$status" -eq 0 ]
	[[ "$output" == *"sdist digests agree for winnow_media-0.0.1.tar.gz"* ]]
	[[ "$output" == *"PEP 740 provenance for winnow_media-0.0.1.tar.gz matches"* ]]
	[[ "$output" == *"Attestation verified for winnow_media-0.0.1.tar.gz (repo ${REPO}, signer workflow ${SDIST_WF})"* ]]
}

@test "verify_sdist_provenance: release digest differing from PyPI fails before attestation" {
	export MOCK_RELEASE_DIGEST="$OTHER_SHA"

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" "$(provenance_json true)"

	[ "$status" -eq 1 ]
	[[ "$output" == *"sdist digest mismatch"* ]]
	[[ "$output" == *"GitHub Release:  ${OTHER_SHA}"* ]]
	! grep -q "^attestation verify" "$MOCK_GH_LOG"
}

@test "verify_sdist_provenance: PyPI digest not matching the file fails" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$OTHER_SHA" "$(provenance_json true)"

	[ "$status" -eq 1 ]
	[[ "$output" == *"PyPI JSON:       ${OTHER_SHA}"* ]]
}

@test "verify_sdist_provenance: PEP 740 publisher mismatch fails" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	local json
	json="$(provenance_json true | sed "s|${REPO}|evil/winnow|")"

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" "$json"

	[ "$status" -eq 1 ]
	[[ "$output" == *"publisher repository 'lgtm-hq/winnow' != 'evil/winnow'"* ]]
}

@test "verify_sdist_provenance: sdist attestation failure fails when required" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	export MOCK_GH_ATTEST_MODE=fail

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" "$(provenance_json true)"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Attestation verification failed for winnow_media-0.0.1.tar.gz"* ]]
}

@test "verify_sdist_provenance: uses the configured tag prefix" {
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	local json
	json="$(provenance_json true | sed 's|"tag-prefix": "v"|"tag-prefix": "release-"|')"

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" "$json"

	[ "$status" -eq 0 ]
	grep -q "releases/tags/release-0.0.1" "$MOCK_GH_LOG"
}

@test "verify_sdist_provenance: an incomplete block is an error, never a skip" {
	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" '{}'
	[ "$status" -eq 1 ]
	[[ "$output" == *"Incomplete provenance block for winnow-media"* ]]
	[ ! -s "$MOCK_GH_LOG" ]

	run verify_sdist_provenance "$SDIST" winnow-media 0.0.1 "$SDIST_SHA" '{"require-attestation": false, "repo": "lgtm-hq/winnow"}'
	[ "$status" -eq 1 ]
	[[ "$output" == *"Incomplete provenance block for winnow-media"* ]]
	[ ! -s "$MOCK_GH_LOG" ]
}

@test "provenance_value: renders booleans as true/false and missing keys as empty" {
	run provenance_value '{"require-attestation": true}' require-attestation
	[ "$output" = "true" ]
	run provenance_value '{"require-attestation": false}' require-attestation
	[ "$output" = "false" ]
	run provenance_value '{}' repo
	[ -z "$output" ]
}
