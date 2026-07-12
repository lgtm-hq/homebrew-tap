#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for check_resource_drift.py Requires-Dist comparison.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
}

teardown() {
	teardown_temp_dir
}

@test "check-resource-drift: passes when Requires-Dist is unchanged" {
	run python3 "$SCRIPTS_DIR/check_resource_drift.py" winnow-media \
		--previous-version 0.0.2 \
		--new-version 0.0.3 \
		--mode fail

	[ "$status" -eq 0 ]
	[[ "$output" == *"No Requires-Dist drift"* ]]
}

@test "check-resource-drift: fails loudly on drift in fail mode" {
	run python3 "$SCRIPTS_DIR/check_resource_drift.py" winnow-media \
		--previous-version 0.0.1 \
		--new-version 0.0.2 \
		--mode fail

	[ "$status" -eq 1 ]
	[[ "$output" == *"Requires-Dist drift detected"* ]]
	[[ "$output" == *"+ click>=8.1"* ]]
	[[ "$output" == *"+ pydantic>=2.0"* ]]
	[[ "$output" == *"Regenerate the resource stanzas"* ]]
}

@test "check-resource-drift: warns but passes when resources regenerate" {
	run python3 "$SCRIPTS_DIR/check_resource_drift.py" winnow-media \
		--previous-version 0.0.1 \
		--new-version 0.0.2 \
		--mode warn

	[ "$status" -eq 0 ]
	[[ "$output" == *"Requires-Dist drift detected"* ]]
	[[ "$output" == *"regenerated automatically"* ]]
}

@test "check-resource-drift: reports removed requirements" {
	run python3 "$SCRIPTS_DIR/check_resource_drift.py" winnow-media \
		--previous-version 0.0.2 \
		--new-version 0.0.1 \
		--mode fail

	[ "$status" -eq 1 ]
	[[ "$output" == *"- click>=8.1"* ]]
	[[ "$output" == *"- pydantic>=2.0"* ]]
}
