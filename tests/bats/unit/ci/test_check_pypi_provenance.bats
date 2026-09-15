#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for the PEP 740 provenance cross-check (check_pypi_provenance.py).

load "../../../helpers/common"

SDIST_SHA="846f7278e1ed929233c9de42a039eb42eb3a633f19517c7b65ed25f4a4ebe343"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
}

teardown() {
	teardown_temp_dir
}

run_check() {
	run python3 "$SCRIPTS_DIR/check_pypi_provenance.py" \
		winnow-media 0.0.1 winnow_media-0.0.1.tar.gz "$@"
}

@test "check_pypi_provenance: matching digest and publisher passes" {
	run_check --sha256 "$SDIST_SHA" --repo lgtm-hq/winnow --workflow publish-pypi-on-tag.yml

	[ "$status" -eq 0 ]
	[[ "$output" == *"PEP 740 provenance for winnow_media-0.0.1.tar.gz matches"* ]]
	[[ "$output" == *"publisher lgtm-hq/winnow / publish-pypi-on-tag.yml"* ]]
}

@test "check_pypi_provenance: workflow is optional" {
	run_check --sha256 "$SDIST_SHA" --repo lgtm-hq/winnow

	[ "$status" -eq 0 ]
}

@test "check_pypi_provenance: digest mismatch fails and names the digest" {
	local other="0000000000000000000000000000000000000000000000000000000000000000"
	run_check --sha256 "$other" --repo lgtm-hq/winnow

	[ "$status" -eq 1 ]
	[[ "$output" == *"does not match"* ]]
	[[ "$output" == *"no attestation subject names winnow_media-0.0.1.tar.gz with sha256 ${other}"* ]]
}

@test "check_pypi_provenance: publisher repository mismatch fails" {
	run_check --sha256 "$SDIST_SHA" --repo evil/winnow

	[ "$status" -eq 1 ]
	[[ "$output" == *"publisher repository 'lgtm-hq/winnow' != 'evil/winnow'"* ]]
}

@test "check_pypi_provenance: publisher workflow mismatch fails" {
	run_check --sha256 "$SDIST_SHA" --repo lgtm-hq/winnow --workflow release.yml

	[ "$status" -eq 1 ]
	[[ "$output" == *"publisher workflow 'publish-pypi-on-tag.yml' != 'release.yml'"* ]]
}

@test "check_pypi_provenance: missing provenance (PyPI 404) fails" {
	run python3 "$SCRIPTS_DIR/check_pypi_provenance.py" \
		winnow-media 0.0.2 winnow_media-0.0.2.tar.gz \
		--sha256 "$SDIST_SHA" --repo lgtm-hq/winnow

	[ "$status" -eq 1 ]
	[[ "$output" == *"PyPI has no PEP 740 provenance for winnow_media-0.0.2.tar.gz"* ]]
}

@test "check_pypi_provenance: provenance without bundles fails" {
	export PYPI_FIXTURE_DIR="$TEST_TEMP_DIR/pypi"
	mkdir -p "$PYPI_FIXTURE_DIR"
	echo '{"version": 1, "attestation_bundles": []}' \
		>"$PYPI_FIXTURE_DIR/winnow-media-0.0.1-winnow_media-0.0.1.tar.gz.provenance.json"

	run_check --sha256 "$SDIST_SHA" --repo lgtm-hq/winnow

	[ "$status" -eq 1 ]
	[[ "$output" == *"provenance has no attestation bundles"* ]]
}
