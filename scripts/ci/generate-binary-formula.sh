#!/usr/bin/env bash
# generate-binary-formula.sh
# Generate a Homebrew formula for binary distribution using product configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/formula-blocks.sh disable=SC1091
source "$SCRIPT_DIR/lib/formula-blocks.sh"
# shellcheck source=lib/lgtm-ci-tooling.sh disable=SC1091
source "$SCRIPT_DIR/lib/lgtm-ci-tooling.sh"
# shellcheck source=lib/pypi-resources.sh disable=SC1091
source "$SCRIPT_DIR/lib/pypi-resources.sh"
# shellcheck source=lib/provenance.sh disable=SC1091
source "$SCRIPT_DIR/lib/provenance.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
	cat <<'EOF'
Generate a Homebrew formula for binary distribution.

The formula installs the arm64 release binary on Apple silicon and, on Intel
Macs, the same version from the PyPI sdist into a Python virtualenv with every
dependency pinned as a resource (config key intel-pypi: python-version,
extras, min-resource-count, wheel-only-packages).

Before anything is pinned the generator verifies the arm64 asset's sha256 and
GitHub attestation, and cross-checks the sdist digest against PyPI JSON, the
GitHub Release asset digest, PyPI's PEP 740 provenance and the sdist
attestation (config block provenance:, see scripts/ci/lib/provenance.sh).

Environment (test seams):
  PYPI_FIXTURE_DIR   Read PyPI JSON from fixtures; the sdist is read from
                     ../sdist/<file> and the arm64 asset from
                     ../assets/<name> next to that directory.
  SKIP_ASSET_VERIFY  Skip the arm64 download, sha256 check and every
                     provenance check (local regeneration only).

Usage: generate-binary-formula.sh --config <formulas/*.yml> --formula-key <key> \
  --version <ver> --output <file> --binary-assets <json>

Options:
  --config          Path to product config YAML
  --formula-key     Formula key under formulas: in the config
  --version         Package version (without v prefix)
  --output          Output formula path
  --binary-assets   JSON object with an arm64-sha key. A legacy x86-sha key
                    is validated but not used: the formula no longer ships
                    an x86_64 binary.
  --pypi-package    Override PyPI package name from config (Intel sdist)
EOF
}

CONFIG_PATH=""
FORMULA_KEY=""
VERSION=""
OUTPUT_FILE=""
BINARY_ASSETS="{}"
PYPI_PACKAGE_OVERRIDE=""

require_option_value() {
	local flag="$1"
	local value="${2:-}"
	if [[ -z "$value" ]]; then
		log_error "Missing value for ${flag}"
		usage
		exit 1
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--config)
		require_option_value "$1" "${2:-}"
		CONFIG_PATH="$2"
		shift 2
		;;
	--formula-key)
		require_option_value "$1" "${2:-}"
		FORMULA_KEY="$2"
		shift 2
		;;
	--version)
		require_option_value "$1" "${2:-}"
		VERSION="$2"
		shift 2
		;;
	--output)
		require_option_value "$1" "${2:-}"
		OUTPUT_FILE="$2"
		shift 2
		;;
	--binary-assets)
		require_option_value "$1" "${2:-}"
		BINARY_ASSETS="$2"
		shift 2
		;;
	--pypi-package)
		require_option_value "$1" "${2:-}"
		PYPI_PACKAGE_OVERRIDE="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
done

if [[ -z "$CONFIG_PATH" || -z "$FORMULA_KEY" || -z "$VERSION" || -z "$OUTPUT_FILE" ]]; then
	log_error "Missing required arguments"
	usage
	exit 1
fi

CONFIG_JSON=$(python3 "$SCRIPT_DIR/read_formula_config.py" "$CONFIG_PATH" --formula-key "$FORMULA_KEY" --json)

read_config_value() {
	python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], '') or '')" "$CONFIG_JSON" "$1"
}

ARM64_SHA=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('arm64-sha', ''))" "$BINARY_ASSETS")
X86_SHA=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('x86-sha', ''))" "$BINARY_ASSETS")

if [[ ! "$ARM64_SHA" =~ ^[0-9a-f]{64}$ ]]; then
	log_error "binary-assets arm64-sha must be a 64-character lowercase hex sha256 value"
	exit 1
fi

# Older release pipelines still send x86-sha alongside arm64-sha. Accept the
# payload so both dispatch shapes work, but the value is unused: Intel Macs
# are served from PyPI, not from an x86_64 release asset.
if [[ -n "$X86_SHA" ]]; then
	if [[ ! "$X86_SHA" =~ ^[0-9a-f]{64}$ ]]; then
		log_error "binary-assets x86-sha, when present, must be a 64-character lowercase hex sha256 value"
		exit 1
	fi
	log_info "Ignoring binary-assets x86-sha: Intel Macs install from PyPI"
fi

BINARY_URL_PATTERN="$(read_config_value binary-url-pattern)"
BINARY_NAMES_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('binary-names', {})))" "$CONFIG_JSON")
INSTALL_NAME="$(read_config_value install-name)"
TEST_COMMAND="$(read_config_value test-command)"
CLASS_NAME="$(read_config_value class-name)"
DESCRIPTION="$(read_config_value description)"
python3 "$SCRIPT_DIR/formula_description.py" "$FORMULA_KEY" "$DESCRIPTION"
HOMEPAGE="$(read_config_value homepage)"
LICENSE="$(read_config_value license)"
TEST_ARGS="${TEST_COMMAND#"${TEST_COMMAND%% *}"}"
TEST_ARGS="${TEST_ARGS# }"

ARM64_ASSET=$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['arm64'])" "$BINARY_NAMES_JSON")

INTEL_PYPI_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('intel-pypi') or {}))" "$CONFIG_JSON")
PYTHON_VERSION=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('python-version', '') or '')" "$INTEL_PYPI_JSON")
PYPI_EXTRAS=$(python3 -c "import json, sys; print(','.join(json.loads(sys.argv[1]).get('extras') or []))" "$INTEL_PYPI_JSON")
if [[ -z "$PYTHON_VERSION" ]]; then
	log_error "intel-pypi.python-version is required in config for ${FORMULA_KEY}"
	exit 1
fi
if [[ ! "$PYTHON_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
	log_error "intel-pypi.python-version must look like 3.13, got '${PYTHON_VERSION}'"
	exit 1
fi
if [[ -n "$PYPI_EXTRAS" && ! "$PYPI_EXTRAS" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]]; then
	log_error "intel-pypi.extras must be a list of extra names for ${FORMULA_KEY}"
	exit 1
fi
INTEL_MIN_RESOURCES=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('min-resource-count', 1) or 1)" "$INTEL_PYPI_JSON")
# intel-pypi may also declare homebrew-deps and wheel-only-packages (same
# shape as a pypi formula entry); the shared resource generator reads them.
PROVENANCE_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('provenance') or {}))" "$CONFIG_JSON")
REQUIRE_ATTESTATION="$(provenance_value "$PROVENANCE_JSON" require-attestation)"
PROVENANCE_REPO="$(provenance_value "$PROVENANCE_JSON" repo)"
BINARY_SIGNER_WORKFLOW="$(provenance_value "$PROVENANCE_JSON" binary-signer-workflow)"
PACKAGE_NAME="${PYPI_PACKAGE_OVERRIDE:-$(read_config_value package)}"
if [[ -z "$PACKAGE_NAME" ]]; then
	log_error "package is required in config for ${FORMULA_KEY} (Intel sdist source)"
	exit 1
fi

build_binary_url() {
	local arch="$1"
	printf '%s\n' "$BINARY_URL_PATTERN" | sed \
		-e 's/{version}/#{version}/g' \
		-e "s/{arch}/${arch}/g"
}

ARM64_URL=$(build_binary_url "arm64")

# Intel Macs install from the PyPI sdist of the same version. PYPI_FIXTURE_DIR
# is the test seam shared with generate-pypi-formula.sh.
if [[ -n "${PYPI_FIXTURE_DIR:-}" ]]; then
	{
		read -r SDIST_URL
		read -r SDIST_SHA
	} < <(python3 "$SCRIPT_DIR/read_pypi_sdist.py" "$PACKAGE_NAME" "$VERSION")
else
	source_lgtm_ci_publish "$REPO_ROOT"
	SDIST_URL=$(get_pypi_download_url "$PACKAGE_NAME" "$VERSION" "false") || true
	SDIST_SHA=$(get_pypi_sha256 "$PACKAGE_NAME" "$VERSION" "false") || true
fi

if [[ -z "${SDIST_URL:-}" || -z "${SDIST_SHA:-}" ]]; then
	log_error "Failed to fetch sdist info for ${PACKAGE_NAME} ${VERSION} from PyPI"
	exit 1
fi
if [[ ! "$SDIST_SHA" =~ ^[0-9a-f]{64}$ ]]; then
	log_error "PyPI sdist sha256 for ${PACKAGE_NAME} ${VERSION} is not a 64-character lowercase hex value"
	exit 1
fi

# Download an asset to <dest> (fixture seam: ../assets/<name> or ../sdist/<name>
# next to PYPI_FIXTURE_DIR).
# Usage: fetch_asset <label> <formula-url> <dest> <fixture-subdir>
fetch_asset() {
	local label="$1"
	local formula_url="$2"
	local dest="$3"
	local fixture_subdir="$4"

	if [[ -n "${PYPI_FIXTURE_DIR:-}" ]]; then
		local fixture_file
		fixture_file="$(dirname "$PYPI_FIXTURE_DIR")/${fixture_subdir}/$(basename "$dest")"
		if [[ ! -f "$fixture_file" ]]; then
			log_error "Missing ${label} fixture: ${fixture_file}"
			return 1
		fi
		cp "$fixture_file" "$dest"
		log_info "Using ${label} fixture: ${fixture_file}"
		return 0
	fi

	# Formula URLs embed the literal Ruby token '#{version}'; substitute the
	# concrete version so the asset can actually be downloaded.
	local download_url="${formula_url//\#\{version\}/$VERSION}"
	log_info "Downloading ${label} asset from ${download_url}"
	if ! curl -sSfL "$download_url" -o "$dest"; then
		log_error "Failed to download ${label} asset from ${download_url}"
		return 1
	fi
}

# Usage: verify_asset_sha <label> <file> <expected-sha>
verify_asset_sha() {
	local label="$1"
	local asset_file="$2"
	local expected_sha="$3"

	local actual_sha
	actual_sha="$(file_sha256 "$asset_file")"
	if [[ "$actual_sha" != "$expected_sha" ]]; then
		log_error "SHA256 mismatch for ${label} asset! Expected: ${expected_sha}, Got: ${actual_sha}"
		return 1
	fi
	log_info "${label} asset sha256 verified"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# The sdist is always fetched: the Intel branch pins its dependency closure,
# which is derived from the sdist metadata.
SDIST_FILE="$TMPDIR/$(basename "$SDIST_URL")"
fetch_asset "sdist" "$SDIST_URL" "$SDIST_FILE" "sdist" || exit 1
verify_asset_sha "sdist" "$SDIST_FILE" "$SDIST_SHA" || exit 1

if [[ -n "${SKIP_ASSET_VERIFY:-}" ]]; then
	log_warning "SKIP_ASSET_VERIFY set; skipping arm64 asset verification and every provenance check"
else
	# 1. arm64 binary: bytes match the dispatched digest AND the asset carries
	#    a GitHub attestation from the configured release workflow.
	ARM64_FILE="$TMPDIR/$ARM64_ASSET"
	fetch_asset "arm64" "$ARM64_URL" "$ARM64_FILE" "assets" || exit 1
	verify_asset_sha "arm64" "$ARM64_FILE" "$ARM64_SHA" || exit 1
	verify_attestation "$ARM64_FILE" "$ARM64_ASSET" "$PROVENANCE_REPO" \
		"$BINARY_SIGNER_WORKFLOW" "$REQUIRE_ATTESTATION" || exit 1

	# 2. sdist: PyPI JSON digest == downloaded digest == GitHub Release digest,
	#    PEP 740 provenance names the same file/digest/publisher, and the sdist
	#    carries an attestation from the configured build workflow.
	verify_sdist_provenance "$SDIST_FILE" "$PACKAGE_NAME" "$VERSION" "$SDIST_SHA" \
		"$PROVENANCE_JSON" || exit 1
fi

log_info "Generating binary formula '${FORMULA_KEY}' for version ${VERSION}"

CAVEATS_TEXT=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('caveats', ''))" "$CONFIG_JSON")
CAVEATS_BLOCK=""
if [[ -n "$CAVEATS_TEXT" ]]; then
	INDENTED_CAVEATS=$(while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -z "$line" ]]; then
			echo ""
		else
			printf '      %s\n' "$line"
		fi
	done <<<"$CAVEATS_TEXT")
	# Starts with a blank line: the placeholder sits at the end of the
	# preceding `end` line (see formula-blocks.sh).
	CAVEATS_BLOCK=$(
		cat <<EOF


  def caveats
    <<~EOS
${INDENTED_CAVEATS}
    EOS
  end
EOF
	)
fi

CONFLICTS_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('conflicts-with') or {}))" "$CONFIG_JSON")
CONFLICTS_BLOCK=$(build_conflicts_block "$CONFLICTS_JSON")

# Intel branch: pin the whole dependency closure (same generator as the
# full PyPI formula), rendered inside the on_intel block, so the install
# step never resolves from PyPI (lgtm-hq/homebrew-tap#471).
log_info "Pinning Intel dependency resources from the sdist..."
generate_pinned_resources "$PACKAGE_NAME" "$SDIST_FILE" "$PYTHON_VERSION" \
	"$INTEL_PYPI_JSON" "$TMPDIR" "$INTEL_MIN_RESOURCES" "$PYPI_EXTRAS" "intel"
# on_macos > on_intel adds two block levels to the class-level stanzas, and
# the install block sits inside the CPU branch.
indent_block 4 "$TMPDIR/resources.txt"
indent_block 4 "$TMPDIR/wheels.txt"
indent_block 2 "$TMPDIR/install_resources.txt"
# The wheel placeholder sits at the end of the resources placeholder, so a
# non-empty wheel block needs its own blank-line separator.
if [[ -s "$TMPDIR/wheels.txt" ]]; then
	printf '\n' | cat - "$TMPDIR/wheels.txt" >"$TMPDIR/wheels.txt.tmp"
	mv "$TMPDIR/wheels.txt.tmp" "$TMPDIR/wheels.txt"
fi
PYPI_EXTRAS_LABEL="${PACKAGE_NAME}${PYPI_EXTRAS:+[${PYPI_EXTRAS}]}"

# Homebrew dependencies of the Intel branch (intel-pypi.homebrew-deps, e.g.
# libyaml for pyyaml) plus the Python runtime, sorted like the full formula.
INTEL_HOMEBREW_DEPS=()
while IFS= read -r line; do
	[[ -n "$line" ]] && INTEL_HOMEBREW_DEPS+=("$line")
done < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1]).get('homebrew-deps') or []))" "$INTEL_PYPI_JSON")
while IFS= read -r dep; do
	echo "      depends_on \"${dep}\""
done < <(printf '%s\n' ${INTEL_HOMEBREW_DEPS[@]+"${INTEL_HOMEBREW_DEPS[@]}"} "python@${PYTHON_VERSION}" | LC_ALL=C sort) >"$TMPDIR/intel_deps.txt"

TEST_EXTRA_RAW=$(read_config_value test-extra)
TEST_EXTRA_BLOCK=$(build_test_extra_block "$TEST_EXTRA_RAW")

# Values that may legitimately be empty (or span multiple lines) are passed
# via --replace-file: render_formula.py rejects empty --replace values, and
# files sidestep any shell-quoting/escaping of the content.
printf '%s' "$CAVEATS_BLOCK" >"$TMPDIR/caveats_block.txt"
printf '%s' "$TEST_ARGS" >"$TMPDIR/test_args.txt"
printf '%s' "$CONFLICTS_BLOCK" >"$TMPDIR/conflicts_block.txt"
printf '%s' "$TEST_EXTRA_BLOCK" >"$TMPDIR/test_extra_block.txt"

python3 "$SCRIPT_DIR/render_formula.py" \
	--template "$SCRIPT_DIR/templates/binary.rb.template" \
	--replace "FORMULA_KEY=${FORMULA_KEY}" \
	--replace "CLASS_NAME=${CLASS_NAME}" \
	--replace "DESCRIPTION=${DESCRIPTION}" \
	--replace "HOMEPAGE=${HOMEPAGE}" \
	--replace "VERSION=${VERSION}" \
	--replace "LICENSE=${LICENSE}" \
	--replace "ARM64_URL=${ARM64_URL}" \
	--replace "ARM64_SHA=${ARM64_SHA}" \
	--replace "SDIST_URL=${SDIST_URL}" \
	--replace "SDIST_SHA=${SDIST_SHA}" \
	--replace "ARM64_ASSET=${ARM64_ASSET}" \
	--replace "PYTHON_VERSION=${PYTHON_VERSION}" \
	--replace "PYPI_EXTRAS_LABEL=${PYPI_EXTRAS_LABEL}" \
	--replace-file "INTEL_DEPS=${TMPDIR}/intel_deps.txt" \
	--replace-file "INTEL_RESOURCES=${TMPDIR}/resources.txt" \
	--replace-file "INTEL_WHEEL_RESOURCES=${TMPDIR}/wheels.txt" \
	--replace-file "INTEL_INSTALL_RESOURCES=${TMPDIR}/install_resources.txt" \
	--replace "INSTALL_NAME=${INSTALL_NAME}" \
	--replace-file "TEST_ARGS=${TMPDIR}/test_args.txt" \
	--replace-file "CAVEATS_BLOCK=${TMPDIR}/caveats_block.txt" \
	--replace-file "CONFLICTS_BLOCK=${TMPDIR}/conflicts_block.txt" \
	--replace-file "TEST_EXTRA_BLOCK=${TMPDIR}/test_extra_block.txt" \
	--output "$OUTPUT_FILE"

log_success "Formula written to ${OUTPUT_FILE}"
