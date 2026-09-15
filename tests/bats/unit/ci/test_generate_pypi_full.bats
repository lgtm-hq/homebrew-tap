#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for full PyPI formula generation with pinned resources (winnow).

load "../../../helpers/common"
load "../../../helpers/mocks"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
}

teardown() {
	teardown_temp_dir
}

@test "generate-pypi-formula: winnow full formula matches fixture" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	output_file="$TEST_TEMP_DIR/winnow.rb"
	full_config="$TEST_TEMP_DIR/winnow-full.yml"

	cat >"$full_config" <<'EOF'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "winnow --version"
EOF

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$full_config" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$output_file"

	[ "$status" -eq 0 ]
	grep -q '# typed: strict' "$output_file"
	grep -q 'resource "click" do' "$output_file"
	grep -q 'venv.pip_install resources' "$output_file"
	! grep -q 'pydantic_core' "$output_file"
	! grep -q 'def caveats' "$output_file"
	assert_files_equal "$REPO_ROOT/tests/fixtures/expected/winnow-full.rb" "$output_file"
}

@test "generate-pypi-formula: wheel-only package absent from dependency tree is skipped" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	output_file="$TEST_TEMP_DIR/winnow.rb"
	full_config="$TEST_TEMP_DIR/winnow-wheels.yml"

	cat >"$full_config" <<'EOF'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "winnow --version"
    wheel-only-packages:
      scipy:
        type: platform
        comment: >-
          scipy requires native compilation - use platform-specific wheels
EOF

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$full_config" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$output_file"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipping wheel package scipy: not in the dependency tree"* ]]
	# With every configured wheel skipped, the plain install path is used
	# and no wheel resource or out-of-band install block is rendered.
	grep -q 'venv.pip_install resources' "$output_file"
	! grep -q 'scipy' "$output_file"
	! grep -q 'wheel_only' "$output_file"
}

@test "read_formula_config: winnow enables pydantic_core wheel-only package" {
	run python3 "$SCRIPTS_DIR/read_formula_config.py" \
		"$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--json

	[ "$status" -eq 0 ]
	run python3 -c "import json, sys; data=json.loads(sys.argv[1]); wheel=data.get('wheel-only-packages', {}); sys.exit(0 if wheel.get('pydantic_core', {}).get('type') == 'platform' else 1)" "$output"
	[ "$status" -eq 0 ]
}

# =============================================================================
# sdist provenance cross-check wiring (#471)
# =============================================================================

SDIST_SHA="846f7278e1ed929233c9de42a039eb42eb3a633f19517c7b65ed25f4a4ebe343"
OTHER_SHA="0000000000000000000000000000000000000000000000000000000000000000"

write_provenance_fixtures() { # $1 = sdist sha advertised by PyPI JSON
	FIXTURES="$TEST_TEMP_DIR/fixtures"
	mkdir -p "$FIXTURES/pypi" "$FIXTURES/sdist"
	cp "$REPO_ROOT/tests/fixtures/pypi/click-8.1.7.json" "$FIXTURES/pypi/"
	cp "$REPO_ROOT/tests/fixtures/pypi/winnow-media-0.0.1-winnow_media-0.0.1.tar.gz.provenance.json" "$FIXTURES/pypi/"
	cp "$REPO_ROOT/tests/fixtures/sdist/winnow-media-0.0.1.tar.gz" "$FIXTURES/sdist/"
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
	export PYPI_FIXTURE_DIR="$FIXTURES/pypi"
	cat >"$TEST_TEMP_DIR/winnow-provenance.yml" <<'YAML'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"
provenance:
  require-attestation: true
  repo: lgtm-hq/winnow
  sdist-signer-workflow: lgtm-hq/lgtm-ci/.github/workflows/reusable-build-python-dist.yml
  pypi-publisher-workflow: publish-pypi-on-tag.yml

formulas:
  winnow:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "winnow --version"
YAML
}

run_generate_provenance() {
	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$TEST_TEMP_DIR/winnow-provenance.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb"
}

@test "generate-pypi-formula: cross-checks the sdist digest and attestation before rendering" {
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	write_provenance_fixtures "$SDIST_SHA"

	run_generate_provenance

	[ "$status" -eq 0 ]
	[[ "$output" == *"sdist digests agree for winnow_media-0.0.1.tar.gz"* ]]
	[[ "$output" == *"PEP 740 provenance for winnow_media-0.0.1.tar.gz matches"* ]]
	[[ "$output" == *"Attestation verified for winnow_media-0.0.1.tar.gz"* ]]
	grep -q 'resource "click" do' "$TEST_TEMP_DIR/winnow.rb"
	grep -q "sha256 \"${SDIST_SHA}\"" "$TEST_TEMP_DIR/winnow.rb"
}

@test "generate-pypi-formula: fails when the GitHub Release digest differs from PyPI" {
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	export MOCK_RELEASE_DIGEST="$OTHER_SHA"
	write_provenance_fixtures "$SDIST_SHA"

	run_generate_provenance

	[ "$status" -ne 0 ]
	[[ "$output" == *"sdist digest mismatch for winnow_media-0.0.1.tar.gz"* ]]
	[[ "$output" == *"GitHub Release:  ${OTHER_SHA}"* ]]
	[ ! -f "$TEST_TEMP_DIR/winnow.rb" ]
}

@test "generate-pypi-formula: fails when the sdist attestation is missing and required" {
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	export MOCK_RELEASE_DIGEST="$SDIST_SHA"
	export MOCK_GH_ATTEST_MODE=missing
	write_provenance_fixtures "$SDIST_SHA"

	run_generate_provenance

	[ "$status" -ne 0 ]
	[[ "$output" == *"Attestation verification failed for winnow_media-0.0.1.tar.gz"* ]]
	[ ! -f "$TEST_TEMP_DIR/winnow.rb" ]
}

@test "generate-pypi-formula: winnow without a provenance block skips the cross-checks" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb"

	[ "$status" -eq 0 ]
	[[ "$output" == *"skipping sdist cross-checks"* ]]
}

@test "generate-pypi-formula: no bottle comment is rendered" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	cat >"$TEST_TEMP_DIR/winnow-head.yml" <<'YAML'
---
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "winnow --version"
    head: true
    bottle-comment: true
YAML

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$TEST_TEMP_DIR/winnow-head.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb"

	[ "$status" -eq 0 ]
	grep -q 'head "https://github.com/lgtm-hq/winnow.git", branch: "main"' "$TEST_TEMP_DIR/winnow.rb"
	! grep -qi 'bottle' "$TEST_TEMP_DIR/winnow.rb"
}
