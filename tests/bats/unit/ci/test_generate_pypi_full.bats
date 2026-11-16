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
	unset GITHUB_ACTIONS SKIP_ASSET_VERIFY
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
  tag-prefix: v
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

@test "generate-pypi-formula: winnow without a provenance block logs the skip" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb"

	[ "$status" -eq 0 ]
	[[ "$output" == *"[WARN]"*"No provenance block in config for winnow"* ]]
}

@test "generate-pypi-formula: an incomplete provenance block fails naming the key" {
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	write_provenance_fixtures "$SDIST_SHA"
	sed -i.bak '/^  tag-prefix: v$/d' "$TEST_TEMP_DIR/winnow-provenance.yml"

	run_generate_provenance

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance.tag-prefix is required for winnow"* ]]
	[ ! -f "$TEST_TEMP_DIR/winnow.rb" ]
}

@test "generate-pypi-formula: provenance: {} and provenance: (null) are errors, not skips" {
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	write_provenance_fixtures "$SDIST_SHA"
	python3 - "$TEST_TEMP_DIR/winnow-provenance.yml" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r"provenance:\n(  .*\n)+", "provenance: {}\n", text)
open(path, "w").write(text)
PY
	grep -q '^provenance: {}$' "$TEST_TEMP_DIR/winnow-provenance.yml"

	run_generate_provenance

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance block for winnow is present but empty"* ]]
	[ ! -f "$TEST_TEMP_DIR/winnow.rb" ]

	sed -i.bak 's/^provenance: {}$/provenance:/' "$TEST_TEMP_DIR/winnow-provenance.yml"

	run_generate_provenance

	[ "$status" -ne 0 ]
	[[ "$output" == *"provenance block for winnow must be a mapping (got NoneType)"* ]]
	[ ! -f "$TEST_TEMP_DIR/winnow.rb" ]
}

@test "generate-pypi-formula: SKIP_ASSET_VERIFY is refused under GitHub Actions" {
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	export GITHUB_ACTIONS=true
	export SKIP_ASSET_VERIFY=1

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$REPO_ROOT/formulas/winnow.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Refusing to skip asset verification under GitHub Actions"* ]]
}

@test "generate-pypi-formula: --skip-asset-verify skips the provenance checks locally" {
	unset GITHUB_ACTIONS
	mock_gh_provenance "$TEST_TEMP_DIR/mock-bin"
	write_provenance_fixtures "$SDIST_SHA"

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$TEST_TEMP_DIR/winnow-provenance.yml" \
		--formula-key winnow \
		--version 0.0.1 \
		--output "$TEST_TEMP_DIR/winnow.rb" \
		--skip-asset-verify

	[ "$status" -eq 0 ]
	[[ "$output" == *"ASSET VERIFICATION DISABLED"* ]]
	[ ! -s "$MOCK_GH_LOG" ]
}

@test "generate-pypi-formula: lintro-full declares no redundant version line" {
	! grep -qE '^  version "' "$REPO_ROOT/Formula/lintro-full.rb"
	! grep -q 'version "' "$SCRIPTS_DIR/templates/pypi-full.rb.template"
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

@test "committed formulas: wheel-only packages render with the PEP 503 name" {
	# winnow.yml keys pillow_heif and pydantic_core; brew audit --strict wants
	# the resource named after the PyPI project (pillow-heif, pydantic-core),
	# and the wheel_only list must use the same spelling.
	formula="$REPO_ROOT/Formula/winnow.rb"
	grep -q '^  resource "pillow-heif" do' "$formula"
	grep -q '^  resource "pydantic-core" do' "$formula"
	! grep -q 'resource "pillow_heif"' "$formula"
	! grep -q 'resource "pydantic_core"' "$formula"
	grep -q 'wheel_only = %w\[numpy pillow pillow-heif pydantic-core pywavelets scipy\]' "$formula"
	grep -q '^  resource "pydantic-core" do' "$REPO_ROOT/Formula/lintro-full.rb"
	grep -q '^      resource "pydantic-core" do' "$REPO_ROOT/Formula/lintro.rb"
	grep -q 'wheel_only = %w\[pydantic-core\]' "$REPO_ROOT/Formula/lintro.rb"
}

# Offline fixture for #633: capme 0.1.0 depends on capbase and on capdep, whose
# only release declares Requires-Python ==3.13.*. All three are built here and
# pip resolves them with PIP_NO_INDEX, so which versions it accepts does not
# depend on the host interpreter or on PyPI's contents. Creating the analysis
# environment is not offline: uv may still fetch the interpreter and pip.
# capme's sdist carries its own build backend (no build requirements).
make_capped_fixtures() {
	CAPPED="$TEST_TEMP_DIR/capped"
	mkdir -p "$CAPPED/pypi" "$CAPPED/sdist" "$CAPPED/links"
	python3 - "$CAPPED" <<'PY'
import hashlib
import io
import json
import sys
import tarfile
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
WHEEL = "Wheel-Version: 1.0\nGenerator: fixture\nRoot-Is-Purelib: true\nTag: py3-none-any\n"


def write_wheel(path, name, version, extra):
    dist = f"{name}-{version}.dist-info"
    files = {
        f"{name}/__init__.py": "",
        f"{dist}/METADATA": f"Metadata-Version: 2.1\nName: {name}\nVersion: {version}\n{extra}",
        f"{dist}/WHEEL": WHEEL,
    }
    record = "".join(f"{entry},,\n" for entry in files) + f"{dist}/RECORD,,\n"
    with zipfile.ZipFile(path, "w") as archive:
        for entry, content in files.items():
            archive.writestr(entry, content)
        archive.writestr(f"{dist}/RECORD", record)


write_wheel(
    root / "links" / "capdep-1.0.0-py3-none-any.whl",
    "capdep",
    "1.0.0",
    "Requires-Python: ==3.13.*\n",
)
# A second, unrestricted dependency, so a formula that takes capdep from a
# wheel still has a resource to generate.
write_wheel(root / "links" / "capbase-1.0.0-py3-none-any.whl", "capbase", "1.0.0", "")
# Required only through capme's optional extra `more`; it requires captool,
# which in turn requires capsub.
write_wheel(
    root / "links" / "capextra-1.0.0-py3-none-any.whl",
    "capextra",
    "1.0.0",
    "Requires-Dist: captool\n",
)
write_wheel(
    root / "links" / "captool-1.0.0-py3-none-any.whl",
    "captool",
    "1.0.0",
    "Requires-Dist: capsub\n",
)
write_wheel(root / "links" / "capsub-1.0.0-py3-none-any.whl", "capsub", "1.0.0", "")

backend = f"""import zipfile

WHEEL = {WHEEL!r}
DIST = "capme-0.1.0.dist-info"
FILES = {{
    "capme/__init__.py": "",
    DIST + "/METADATA": "Metadata-Version: 2.1\\nName: capme\\nVersion: 0.1.0\\nRequires-Dist: capdep\\nRequires-Dist: capbase\\nProvides-Extra: more\\nRequires-Dist: capextra; extra == 'more'\\n",
    DIST + "/WHEEL": WHEEL,
}}


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    name = "capme-0.1.0-py3-none-any.whl"
    record = "".join(entry + ",,\\n" for entry in FILES) + DIST + "/RECORD,,\\n"
    with zipfile.ZipFile(wheel_directory + "/" + name, "w") as archive:
        for entry, content in FILES.items():
            archive.writestr(entry, content)
        archive.writestr(DIST + "/RECORD", record)
    return name
"""
sources = {
    "pyproject.toml": '[build-system]\nrequires = []\nbuild-backend = "fixture_backend"\nbackend-path = ["."]\n',
    "fixture_backend.py": backend,
    "PKG-INFO": "Metadata-Version: 2.1\nName: capme\nVersion: 0.1.0\n",
}
sdist = root / "sdist" / "capme-0.1.0.tar.gz"
with tarfile.open(sdist, "w:gz") as archive:
    for entry, content in sources.items():
        data = content.encode()
        info = tarfile.TarInfo(f"capme-0.1.0/{entry}")
        info.size = len(data)
        archive.addfile(info, io.BytesIO(data))


def release(name, version, sha):
    return {
        "info": {"name": name, "version": version, "requires_dist": None},
        "urls": [
            {
                "packagetype": "sdist",
                "filename": f"{name}-{version}.tar.gz",
                "url": f"https://files.pythonhosted.org/packages/fx/00/{name}-{version}.tar.gz",
                "digests": {"sha256": sha},
            }
        ],
    }


(root / "pypi" / "capme-0.1.0.json").write_text(
    json.dumps(release("capme", "0.1.0", hashlib.sha256(sdist.read_bytes()).hexdigest()))
)
(root / "pypi" / "capdep-1.0.0.json").write_text(json.dumps(release("capdep", "1.0.0", "c3" * 32)))
(root / "pypi" / "capbase-1.0.0.json").write_text(json.dumps(release("capbase", "1.0.0", "d4" * 32)))
for extra_name, digest in (("capextra", "e5"), ("captool", "f6"), ("capsub", "a7")):
    (root / "pypi" / f"{extra_name}-1.0.0.json").write_text(
        json.dumps(release(extra_name, "1.0.0", digest * 32)),
    )
PY
	export PYPI_FIXTURE_DIR="$CAPPED/pypi"
	# Host pip settings must not change what the fixture proves.
	unset PIP_IGNORE_REQUIRES_PYTHON PIP_INDEX_URL PIP_EXTRA_INDEX_URL PIP_PYTHON_VERSION
	export PIP_NO_INDEX=1 PIP_FIND_LINKS="$CAPPED/links" PIP_DISABLE_PIP_VERSION_CHECK=1
}

run_generate_capme() { # $1 = python-version
	CAPME_CONFIG="$TEST_TEMP_DIR/capme.yml"
	CAPME_OUTPUT="$TEST_TEMP_DIR/capme.rb"
	cat >"$CAPME_CONFIG" <<YAML
---
package: capme
source-repo: lgtm-hq/capme
homepage: https://github.com/lgtm-hq/capme
license: MIT
description: "Fixture package whose dependency supports one Python only"

formulas:
  capme:
    type: pypi
    generate-resources: true
    python-version: "$1"
    test-command: "capme --version"
YAML
	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$CAPME_CONFIG" \
		--formula-key capme \
		--version 0.1.0 \
		--output "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: a dependency capped to the formula's Python resolves whatever the host runs" {
	# The reported failure (#633): pip applied a dependency's Requires-Python
	# against the generator host's interpreter. capdep only installs on
	# Python 3.13, so this passes only when pip runs under the configured 3.13.
	make_capped_fixtures

	run_generate_capme "3.13"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Analysis environment: Python 3.13"* ]]
	grep -q 'depends_on "python@3.13"' "$CAPME_OUTPUT"
	grep -q 'resource "capdep" do' "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: the same dependency is refused when the formula declares another Python" {
	# Proof that the configured interpreter, not the host's, decides: the
	# identical fixture must fail for a 3.14 formula on every host.
	make_capped_fixtures

	run_generate_capme "3.14"

	[ "$status" -ne 0 ]
	# pip's own reason, so a failure for any other cause does not pass this.
	[[ "$output" == *"capdep"* ]]
	[[ "$output" == *"requires a different Python"* ]]
	[[ "$output" == *"pip could not install capme and its dependencies under Python 3.14"* ]]
	[ ! -f "$CAPME_OUTPUT" ]
}

# #639: a universal wheel-only package must be pinned to the version pip
# resolved, like a platform one. capdep resolves to 1.0.0 (the only wheel pip
# can find), while the project document says the newest release is 2.0.0.
universal_release() { # $1 = version; prints a release document with a universal wheel
	jq -cn --arg v "$1" '{
		info: {name: "capdep", version: $v},
		urls: [{
			packagetype: "bdist_wheel",
			filename: "capdep-\($v)-py3-none-any.whl",
			url: "https://files.pythonhosted.org/packages/fx/00/capdep-\($v)-py3-none-any.whl",
			digests: {sha256: (if $v == "1.0.0" then "a1" else "b2" end * 32)}
		}]
	}'
}

run_generate_capme_universal() {
	CAPME_CONFIG="$TEST_TEMP_DIR/capme.yml"
	CAPME_OUTPUT="$TEST_TEMP_DIR/capme.rb"
	cat >"$CAPME_CONFIG" <<YAML
---
package: capme
source-repo: lgtm-hq/capme
homepage: https://github.com/lgtm-hq/capme
license: MIT
description: "Fixture package with a universal wheel-only dependency"

formulas:
  capme:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "capme --version"
    wheel-only-packages:
      capdep:
        type: universal
        comment: 'capdep - use wheel'
YAML
	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$CAPME_CONFIG" \
		--formula-key capme \
		--version 0.1.0 \
		--output "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: a universal wheel is pinned to the resolved version, not the newest release" {
	make_capped_fixtures
	universal_release 1.0.0 >"$PYPI_FIXTURE_DIR/capdep-1.0.0.json"
	universal_release 2.0.0 >"$PYPI_FIXTURE_DIR/capdep.json"

	run_generate_capme_universal

	[ "$status" -eq 0 ]
	grep -q 'capdep-1.0.0-py3-none-any.whl' "$CAPME_OUTPUT"
	grep -q "sha256 \"$(printf 'a1%.0s' {1..32})\"" "$CAPME_OUTPUT"
	[ "$(grep -c 'capdep-2.0.0' "$CAPME_OUTPUT")" -eq 0 ]
	# One stanza only: the wheel, not an sdist resource beside it.
	[ "$(grep -c 'resource "capdep" do' "$CAPME_OUTPUT")" -eq 1 ]
	grep -q 'resource "capbase" do' "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: no universal wheel at the resolved version fails naming it" {
	# 1.0.0 publishes an sdist only (the shared fixture); the newest release
	# has a wheel. Pinning that one instead would hide the problem.
	make_capped_fixtures
	universal_release 2.0.0 >"$PYPI_FIXTURE_DIR/capdep.json"

	run_generate_capme_universal

	[ "$status" -ne 0 ]
	[[ "$output" == *"No universal wheel found for capdep 1.0.0"* ]]
	[ ! -f "$CAPME_OUTPUT" ]
}

# #641: a pypi formula can declare extras of its package. capme's extra `more`
# pulls in capextra -> captool -> capsub.
run_generate_capme_extras() { # $1 = the YAML lines for extras and homebrew-deps
	CAPME_CONFIG="$TEST_TEMP_DIR/capme.yml"
	CAPME_OUTPUT="$TEST_TEMP_DIR/capme.rb"
	cat >"$CAPME_CONFIG" <<YAML
---
package: capme
source-repo: lgtm-hq/capme
homepage: https://github.com/lgtm-hq/capme
license: MIT
description: "Fixture package with an optional extra"

formulas:
  capme:
    type: pypi
    generate-resources: true
    python-version: "3.13"
    test-command: "capme --version"
$1
YAML
	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$CAPME_CONFIG" \
		--formula-key capme \
		--version 0.1.0 \
		--output "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: a configured extra's dependencies are pinned and the formula installs with it" {
	make_capped_fixtures

	run_generate_capme_extras "    extras:
      - more"

	[ "$status" -eq 0 ]
	grep -q 'resource "capextra" do' "$CAPME_OUTPUT"
	grep -q 'resource "captool" do' "$CAPME_OUTPUT"
	grep -q 'resource "capsub" do' "$CAPME_OUTPUT"
	grep -q 'venv.pip_install_and_link "#{buildpath}\[more\]"' "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: without extras the extra's dependencies are absent and the install line is unchanged" {
	make_capped_fixtures

	run_generate_capme_extras ""

	[ "$status" -eq 0 ]
	grep -q 'resource "capdep" do' "$CAPME_OUTPUT"
	[ "$(grep -c 'capextra\|captool\|capsub' "$CAPME_OUTPUT")" -eq 0 ]
	grep -q '^    venv.pip_install_and_link buildpath$' "$CAPME_OUTPUT"
}

@test "generate-pypi-formula: what only a Homebrew dependency of the extra needs is not pinned" {
	# captool is provided by a Homebrew formula: neither it nor capsub, which
	# only captool requires, becomes a resource. capextra still does.
	make_capped_fixtures

	run_generate_capme_extras "    extras:
      - more
    homebrew-deps:
      - captool"

	[ "$status" -eq 0 ]
	grep -q 'depends_on "captool"' "$CAPME_OUTPUT"
	grep -q 'resource "capextra" do' "$CAPME_OUTPUT"
	[ "$(grep -c 'resource "captool" do' "$CAPME_OUTPUT")" -eq 0 ]
	[ "$(grep -c 'resource "capsub" do' "$CAPME_OUTPUT")" -eq 0 ]
}

@test "generate-pypi-formula: extras that are not a list of extra names are refused before anything is fetched" {
	make_capped_fixtures

	local declared
	for declared in \
		'    extras: more' \
		'    extras:
      - "more]; evil"' \
		'    extras:
      - ""' \
		'    extras:
      - 1' \
		'    extras:
      more: true'; do
		run_generate_capme_extras "$declared"

		[ "$status" -ne 0 ]
		[[ "$output" == *"extras for capme must be a list of extra names"* ]]
		[[ "$output" != *"Creating temporary venv"* ]]
		[ ! -f "$CAPME_OUTPUT" ]
	done
}

@test "generate-pypi-formula: extras without generate-resources are refused" {
	make_capped_fixtures
	CAPME_CONFIG="$TEST_TEMP_DIR/capme.yml"
	cat >"$CAPME_CONFIG" <<'YAML'
---
package: capme
source-repo: lgtm-hq/capme
homepage: https://github.com/lgtm-hq/capme
license: MIT
description: "Fixture package with an optional extra"

formulas:
  capme:
    type: pypi
    python-version: "3.13"
    test-command: "capme --version"
    extras:
      - more
YAML

	run bash "$SCRIPTS_DIR/generate-pypi-formula.sh" \
		--config "$CAPME_CONFIG" --formula-key capme --version 0.1.0 \
		--output "$TEST_TEMP_DIR/capme.rb"

	[ "$status" -ne 0 ]
	[[ "$output" == *"extras for capme need generate-resources: true"* ]]
}

@test "committed formulas: lintro-full installs the tools its caveats call bundled" {
	# #641: the caveats promised pydoclint while the formula had no such
	# resource. Every tool named as bundled must be a resource, and the tools
	# Homebrew provides must not be pinned a second time.
	local formula="$REPO_ROOT/Formula/lintro-full.rb"
	local config="$REPO_ROOT/formulas/lintro.yml"

	local bundled
	bundled="$(grep '(bundled, run by lintro)' "$formula")"
	[ -n "$bundled" ]
	local tool count=0
	for tool in $(printf '%s\n' "$bundled" | sed -e 's/(bundled.*//' -e 's/,/ /g'); do
		grep -q "resource \"$tool\" do" "$formula"
		count=$((count + 1))
	done
	[ "$count" -eq 3 ]
	grep -q 'resource "pydoclint" do' "$formula"
	grep -q 'resource "pylint" do' "$formula"
	grep -q 'resource "import-linter" do' "$formula"

	for tool in ruff black mypy bandit yamllint; do
		grep -q "depends_on \"$tool\"" "$formula"
		[ "$(grep -c "resource \"$tool\" do" "$formula")" -eq 0 ]
	done

	# lintro looks these three up on PATH, and resources are not linked: the
	# command must be a launcher that adds the formula's own environment.
	grep -q 'venv.pip_install "#{buildpath}\[full\]"' "$formula"
	grep -q '^    launcher_path = "${PATH}:#{libexec}/bin"$' "$formula"
	grep -q '^    (bin/"lintro").write_env_script libexec/"bin/lintro", PATH: launcher_path$' "$formula"
	[ "$(grep -c 'pip_install_and_link' "$formula")" -eq 0 ]
	# brew test proves it on an installed formula.
	grep -q 'refute_match "not found in PATH", bundled_out' "$formula"
	# The caveats in the formula are the config's.
	grep -q 'pydoclint, pylint, import-linter (bundled, run by lintro)' "$config"
}

@test "generate-pypi-formula: venv-bin-on-path installs the command as a launcher that appends the environment to PATH" {
	make_capped_fixtures

	run_generate_capme_extras "    venv-bin-on-path: true"

	[ "$status" -eq 0 ]
	grep -q '^    venv.pip_install buildpath$' "$CAPME_OUTPUT"
	grep -q '^    launcher_path = "${PATH}:#{libexec}/bin"$' "$CAPME_OUTPUT"
	grep -q '^    (bin/"capme").write_env_script libexec/"bin/capme", PATH: launcher_path$' "$CAPME_OUTPUT"
	[ "$(grep -c 'pip_install_and_link' "$CAPME_OUTPUT")" -eq 0 ]
	# No hand-aligned continuation line, whatever the command's length.
	[ "$(awk 'length > 118' "$CAPME_OUTPUT" | wc -l)" -eq 0 ]

	local declared
	for declared in 'sometimes' '1' '"true"'; do
		run_generate_capme_extras "    venv-bin-on-path: $declared"

		[ "$status" -ne 0 ]
		[[ "$output" == *"venv-bin-on-path for capme must be true or false"* ]]
	done
}

@test "generate-pypi-formula: homebrew-deps entries that are not names are refused, not dropped" {
	# Reading the list failed on a mapping inside a process substitution,
	# and the formula rendered without any depends_on line.
	make_capped_fixtures

	run_generate_capme_extras "    homebrew-deps:
      - name: captool
        build: true"

	[ "$status" -ne 0 ]
	[[ "$output" == *"homebrew-deps for capme"* ]]
	[ ! -f "$CAPME_OUTPUT" ]
}

@test "generate-pypi-formula: an empty or null extras list means no extras" {
	make_capped_fixtures

	local declared
	for declared in '    extras: []' '    extras:'; do
		run_generate_capme_extras "$declared"

		[ "$status" -eq 0 ]
		[ "$(grep -c 'capextra' "$CAPME_OUTPUT")" -eq 0 ]
		grep -q '^    venv.pip_install_and_link buildpath$' "$CAPME_OUTPUT"
	done
}
