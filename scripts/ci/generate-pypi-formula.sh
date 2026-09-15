#!/usr/bin/env bash
# generate-pypi-formula.sh
# Generate a Homebrew formula from PyPI using product configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

usage() {
	cat <<'EOF'
Generate a Homebrew formula from PyPI.

Usage: generate-pypi-formula.sh --config <formulas/*.yml> --formula-key <key> --version <ver> --output <file>

Options:
  --config         Path to product config YAML (formulas/<product>.yml)
  --formula-key    Formula key under formulas: in the config
  --version        Package version (without v prefix)
  --output         Output formula path (e.g., Formula/winnow.rb)
  --pypi-package   Override PyPI package name from config
  --skip-asset-verify
                   Local regeneration only: skip every provenance check.
                   Refused under GitHub Actions.

Before rendering, the sdist digest is cross-checked against the GitHub
Release asset digest and PyPI's PEP 740 provenance, and its attestation is
verified (config block provenance:, see scripts/ci/lib/provenance.sh).

Environment (test seams):
  PYPI_FIXTURE_DIR   Read PyPI JSON from fixtures; the sdist comes from
                     ../sdist/ next to that directory when present.
  SKIP_ASSET_VERIFY  Same as --skip-asset-verify; only the literal value 1
                     is accepted, and never under GitHub Actions.
EOF
}

CONFIG_PATH=""
FORMULA_KEY=""
VERSION=""
OUTPUT_FILE=""
PYPI_PACKAGE_OVERRIDE=""
SKIP_VERIFY_FLAG="false"

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
	--pypi-package)
		require_option_value "$1" "${2:-}"
		PYPI_PACKAGE_OVERRIDE="$2"
		shift 2
		;;
	--skip-asset-verify)
		SKIP_VERIFY_FLAG="true"
		shift
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

PACKAGE_NAME="${PYPI_PACKAGE_OVERRIDE:-$(read_config_value package)}"
PYTHON_VERSION="$(read_config_value python-version)"
PYTHON_VERSION="${PYTHON_VERSION:-3.13}"
MIN_RESOURCE_COUNT="$(read_config_value min-resource-count)"
MIN_RESOURCE_COUNT="${MIN_RESOURCE_COUNT:-1}"
GENERATE_RESOURCES=$(python3 -c "import json, sys; print('true' if json.loads(sys.argv[1]).get('generate-resources') else 'false')" "$CONFIG_JSON")
TEST_COMMAND="$(read_config_value test-command)"
if [[ -z "$TEST_COMMAND" ]]; then
	log_error "test-command is required in config for ${FORMULA_KEY}"
	exit 1
fi
CLASS_NAME="$(read_config_value class-name)"
DESCRIPTION="$(read_config_value description)"
python3 "$SCRIPT_DIR/formula_description.py" "$FORMULA_KEY" "$DESCRIPTION"
HOMEPAGE="$(read_config_value homepage)"
LICENSE="$(read_config_value license)"
TEST_BINARY="${TEST_COMMAND%% *}"

log_info "Generating PyPI formula '${FORMULA_KEY}' for ${PACKAGE_NAME} ${VERSION}"

if [[ -n "${PYPI_FIXTURE_DIR:-}" ]]; then
	{
		read -r TARBALL_URL
		read -r TARBALL_SHA
	} < <(python3 "$SCRIPT_DIR/read_pypi_sdist.py" "$PACKAGE_NAME" "$VERSION")
else
	source_lgtm_ci_publish "$REPO_ROOT"
	TARBALL_URL=$(get_pypi_download_url "$PACKAGE_NAME" "$VERSION" "false") || true
	TARBALL_SHA=$(get_pypi_sha256 "$PACKAGE_NAME" "$VERSION" "false") || true
fi

if [[ -z "$TARBALL_URL" ]] || [[ -z "$TARBALL_SHA" ]]; then
	log_error "Failed to fetch tarball info from PyPI"
	exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

validate_sdist() {
	local tarball_file="$1"

	if [[ -n "${PYPI_FIXTURE_DIR:-}" ]]; then
		local fixture_sdist
		fixture_sdist="$(dirname "$PYPI_FIXTURE_DIR")/sdist/${PACKAGE_NAME}-${VERSION}.tar.gz"
		if [[ ! -f "$fixture_sdist" ]]; then
			fixture_sdist="$(dirname "$PYPI_FIXTURE_DIR")/sdist/$(basename "$tarball_file")"
		fi
		if [[ -f "$fixture_sdist" ]]; then
			cp "$fixture_sdist" "$tarball_file"
			log_info "Using sdist fixture: ${fixture_sdist}"
			return 0
		fi
		log_info "Skipping live sdist download in fixture mode"
		return 0
	fi

	log_info "Validating sdist checksum..."
	if ! curl -sSfL "$TARBALL_URL" -o "$tarball_file"; then
		log_error "Failed to download tarball from $TARBALL_URL"
		exit 1
	fi

	local actual_sha
	if command -v sha256sum &>/dev/null; then
		actual_sha=$(sha256sum "$tarball_file" | cut -d' ' -f1)
	else
		actual_sha=$(shasum -a 256 "$tarball_file" | cut -d' ' -f1)
	fi
	if [[ "$actual_sha" != "$TARBALL_SHA" ]]; then
		log_error "SHA256 mismatch! Expected: $TARBALL_SHA, Got: $actual_sha"
		exit 1
	fi
}

# PyPI names the sdist <normalized_name>-<version>.tar.gz; the provenance
# checks look the same filename up on the GitHub Release and at PyPI's
# integrity API, so keep the real filename rather than the config name.
TARBALL_FILE="$TMPDIR/$(basename "$TARBALL_URL")"
validate_sdist "$TARBALL_FILE"

# Cross-check what will be pinned: GitHub Release digest, PEP 740 provenance
# and the sdist attestation (scripts/ci/lib/provenance.sh). Skipped in the
# fixture seam when no sdist file is available.
# PROVENANCE_PRESENT tells "key absent everywhere" (checks not adopted) apart
# from a present but null/empty/non-mapping value, which provenance_mode
# rejects.
PROVENANCE_PRESENT=$(python3 -c "import json, sys; print('true' if 'provenance' in json.loads(sys.argv[1]) else 'false')" "$CONFIG_JSON")
PROVENANCE_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('provenance')))" "$CONFIG_JSON")
SKIP_VERIFY="$(resolve_skip_asset_verify "$SKIP_VERIFY_FLAG")" || exit 1
if [[ "$SKIP_VERIFY" != "true" ]]; then
	# An incomplete provenance block is an error; no block at all means the
	# product has not adopted the checks yet (logged).
	PROVENANCE_MODE="$(provenance_mode "$PROVENANCE_JSON" pypi "$FORMULA_KEY" "$PROVENANCE_PRESENT")" || exit 1
	if [[ "$PROVENANCE_MODE" == "skip" ]]; then
		log_warning "No provenance block in config for ${FORMULA_KEY}: sdist cross-checks not run (sha256 check only)"
	elif [[ -f "$TARBALL_FILE" ]]; then
		verify_sdist_provenance "$TARBALL_FILE" "$PACKAGE_NAME" "$VERSION" "$TARBALL_SHA" "$PROVENANCE_JSON"
	else
		log_info "No sdist file available in fixture mode; skipping provenance cross-checks"
	fi
fi

if [[ "$GENERATE_RESOURCES" == "true" ]]; then
	generate_pinned_resources "$PACKAGE_NAME" "$TARBALL_FILE" "$PYTHON_VERSION" \
		"$CONFIG_JSON" "$TMPDIR" "$MIN_RESOURCE_COUNT"

	HOMEBREW_PKG_ARRAY=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && HOMEBREW_PKG_ARRAY+=("$line")
	done < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1]).get('homebrew-deps', [])))" "$CONFIG_JSON")

	CAVEATS_RAW=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('caveats', '') or '')" "$CONFIG_JSON")
	if [[ -n "$CAVEATS_RAW" ]]; then
		INDENTED_CAVEATS=$(while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ -z "$line" ]]; then
				echo ""
			else
				printf '      %s\n' "$line"
			fi
		done <<<"$CAVEATS_RAW")
		CAVEATS_BLOCK=$(
			cat <<EOF

  def caveats
    <<~EOS
${INDENTED_CAVEATS}
    EOS
  end
EOF
		)
	else
		CAVEATS_BLOCK=""
	fi

	HEAD_ENABLED=$(python3 -c "import json, sys; print('true' if json.loads(sys.argv[1]).get('head') else 'false')" "$CONFIG_JSON")
	HEAD_BLOCK=""
	if [[ "$HEAD_ENABLED" == "true" ]]; then
		SOURCE_REPO="$(read_config_value source-repo)"
		HEAD_BRANCH="$(read_config_value head-branch)"
		HEAD_BLOCK=$(build_head_block "$SOURCE_REPO" "${HEAD_BRANCH:-main}")
	fi

	CONFLICTS_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('conflicts-with') or {}))" "$CONFIG_JSON")
	CONFLICTS_BLOCK=$(build_conflicts_block "$CONFLICTS_JSON")

	TEST_EXTRA_RAW=$(read_config_value test-extra)
	TEST_EXTRA_BLOCK=$(build_test_extra_block "$TEST_EXTRA_RAW")

	printf '%s' "$CAVEATS_BLOCK" >"$TMPDIR/caveats_block.txt"
	printf '%s' "$HEAD_BLOCK" >"$TMPDIR/head_block.txt"
	printf '%s' "$CONFLICTS_BLOCK" >"$TMPDIR/conflicts_block.txt"
	printf '%s' "$TEST_EXTRA_BLOCK" >"$TMPDIR/test_extra_block.txt"

	# The python dependency sorts into the list alphabetically, matching the
	# committed formulae (and brew audit's dependency-order expectations).
	while IFS= read -r dep; do
		if [[ "$dep" == "rust" ]]; then
			echo '  depends_on "rust" # provides clippy, rustfmt, and cargo for cargo-audit'
		else
			echo "  depends_on \"${dep}\""
		fi
	done < <(printf '%s\n' ${HOMEBREW_PKG_ARRAY[@]+"${HOMEBREW_PKG_ARRAY[@]}"} "python@${PYTHON_VERSION}" | LC_ALL=C sort) >"$TMPDIR/deps.txt"

	python3 "$SCRIPT_DIR/render_formula.py" \
		--template "$SCRIPT_DIR/templates/pypi-full.rb.template" \
		--replace "FORMULA_KEY=${FORMULA_KEY}" \
		--replace "CLASS_NAME=${CLASS_NAME}" \
		--replace "DESCRIPTION=${DESCRIPTION}" \
		--replace "HOMEPAGE=${HOMEPAGE}" \
		--replace "TARBALL_URL=${TARBALL_URL}" \
		--replace "TARBALL_SHA=${TARBALL_SHA}" \
		--replace "LICENSE=${LICENSE}" \
		--replace "PYTHON_VENV=python${PYTHON_VERSION}" \
		--replace "TEST_BINARY=${TEST_BINARY}" \
		--replace-file "HOMEBREW_DEPS=${TMPDIR}/deps.txt" \
		--replace-file "POET_RESOURCES=${TMPDIR}/resources.txt" \
		--replace-file "WHEEL_RESOURCES=${TMPDIR}/wheels.txt" \
		--replace-file "INSTALL_RESOURCES=${TMPDIR}/install_resources.txt" \
		--replace-file "CAVEATS_BLOCK=${TMPDIR}/caveats_block.txt" \
		--replace-file "HEAD_BLOCK=${TMPDIR}/head_block.txt" \
		--replace-file "CONFLICTS_BLOCK=${TMPDIR}/conflicts_block.txt" \
		--replace-file "TEST_EXTRA_BLOCK=${TMPDIR}/test_extra_block.txt" \
		--output "$OUTPUT_FILE"
else
	python3 "$SCRIPT_DIR/render_formula.py" \
		--template "$SCRIPT_DIR/templates/pypi-simple.rb.template" \
		--replace "FORMULA_KEY=${FORMULA_KEY}" \
		--replace "CLASS_NAME=${CLASS_NAME}" \
		--replace "DESCRIPTION=${DESCRIPTION}" \
		--replace "HOMEPAGE=${HOMEPAGE}" \
		--replace "TARBALL_URL=${TARBALL_URL}" \
		--replace "TARBALL_SHA=${TARBALL_SHA}" \
		--replace "LICENSE=${LICENSE}" \
		--replace "PYTHON_VERSION=${PYTHON_VERSION}" \
		--replace "PYTHON_VENV=python${PYTHON_VERSION}" \
		--replace "TEST_BINARY=${TEST_BINARY}" \
		--output "$OUTPUT_FILE"
fi

log_success "Formula written to ${OUTPUT_FILE}"
