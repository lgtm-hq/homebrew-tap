#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for scripts/ci/fetch_wheel_info.py and the matching
# pypi_canonical_name helper: wheel resources are named after the PEP 503
# normalized PyPI project name (brew audit --strict rejects pydantic_core).

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	# shellcheck source=../../../../scripts/ci/lib/pypi-resources.sh disable=SC1091
	source "$SCRIPTS_DIR/lib/pypi-resources.sh"
}

teardown() {
	teardown_temp_dir
}

@test "fetch_wheel_info: platform stanza is named after the normalized PyPI name" {
	run python3 "$SCRIPTS_DIR/fetch_wheel_info.py" pydantic_core \
		--type platform --version 2.46.5 \
		--comment "pydantic_core requires Rust to build - use platform-specific wheels"

	[ "$status" -eq 0 ]
	[[ "$output" == *'  resource "pydantic-core" do'* ]]
	[[ "$output" != *'resource "pydantic_core"'* ]]
	# The lookup still uses the configured spelling; only the stanza is normalized.
	[[ "$output" == *"pydantic_core-2.46.5-cp313-cp313-macosx_11_0_arm64.whl"* ]]
	[[ "$output" == *"pydantic_core-2.46.5-cp313-cp313-macosx_10_12_x86_64.whl"* ]]
	[[ "$output" == *"# pydantic_core requires Rust to build"* ]]
}

@test "fetch_wheel_info: single-arch stanza is named after the normalized PyPI name" {
	run python3 "$SCRIPTS_DIR/fetch_wheel_info.py" pydantic_core \
		--type platform --version 2.46.5 --arch intel

	[ "$status" -eq 0 ]
	[[ "$output" == *'  resource "pydantic-core" do'* ]]
	[[ "$output" == *"macosx_10_12_x86_64.whl"* ]]
	[[ "$output" != *"arm64"* ]]
}

@test "fetch_wheel_info: universal stanza lowercases and collapses separators" {
	run python3 "$SCRIPTS_DIR/fetch_wheel_info.py" Some_Pkg.Name \
		--type universal --version 1.0.0

	[ "$status" -eq 0 ]
	[[ "$output" == *'  resource "some-pkg-name" do'* ]]
	[[ "$output" == *"some_pkg_name-1.0.0-py3-none-any.whl"* ]]
	# The default comment keeps the configured spelling for readability.
	[[ "$output" == *"# Some_Pkg.Name - using wheel"* ]]
}

@test "pypi_canonical_name: matches the stanza naming so wheel_only rejects the right resources" {
	[ "$(pypi_canonical_name pydantic_core)" = "pydantic-core" ]
	[ "$(pypi_canonical_name pillow_heif)" = "pillow-heif" ]
	[ "$(pypi_canonical_name Some_Pkg.Name)" = "some-pkg-name" ]
	[ "$(pypi_canonical_name a--b__c..d)" = "a-b-c-d" ]
	[ "$(pypi_canonical_name scipy)" = "scipy" ]
}
