#!/usr/bin/env bash
# generate-pypi-formula.sh
# Generate a Homebrew formula from PyPI using product configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

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
EOF
}

CONFIG_PATH=""
FORMULA_KEY=""
VERSION=""
OUTPUT_FILE=""
PYPI_PACKAGE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--config)
		CONFIG_PATH="$2"
		shift 2
		;;
	--formula-key)
		FORMULA_KEY="$2"
		shift 2
		;;
	--version)
		VERSION="$2"
		shift 2
		;;
	--output)
		OUTPUT_FILE="$2"
		shift 2
		;;
	--pypi-package)
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

PACKAGE_NAME="${PYPI_PACKAGE_OVERRIDE:-$(read_config_value package)}"
PYTHON_VERSION="$(read_config_value python-version)"
PYTHON_VERSION="${PYTHON_VERSION:-3.13}"
PYTHON_VERSION_DOT="${PYTHON_VERSION//./}"
GENERATE_RESOURCES=$(python3 -c "import json, sys; print('true' if json.loads(sys.argv[1]).get('generate-resources') else 'false')" "$CONFIG_JSON")
TEST_COMMAND="$(read_config_value test-command)"
CLASS_NAME="$(read_config_value class-name)"
DESCRIPTION="$(read_config_value description)"
HOMEPAGE="$(read_config_value homepage)"
LICENSE="$(read_config_value license)"
TEST_BINARY="${TEST_COMMAND%% *}"

log_info "Generating PyPI formula '${FORMULA_KEY}' for ${PACKAGE_NAME} ${VERSION}"

{
	read -r TARBALL_URL
	read -r TARBALL_SHA
} < <(python3 "$SCRIPT_DIR/fetch_package_info.py" "$PACKAGE_NAME" "$VERSION")

if [[ -z "$TARBALL_URL" ]] || [[ -z "$TARBALL_SHA" ]]; then
	log_error "Failed to fetch tarball info from PyPI"
	exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [[ "$GENERATE_RESOURCES" == "true" ]]; then
	HOMEBREW_DEPS_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('homebrew-deps', [])))" "$CONFIG_JSON")
	WHEEL_PACKAGES_JSON=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('wheel-only-packages', {})))" "$CONFIG_JSON")

	mapfile -t HOMEBREW_PKG_ARRAY < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1])))" "$HOMEBREW_DEPS_JSON")
	mapfile -t WHEEL_PKG_ARRAY < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1]).keys()))" "$WHEEL_PACKAGES_JSON")

	ANALYSIS_VENV=$(mktemp -d)
	trap 'rm -rf "$TMPDIR" "$ANALYSIS_VENV"' EXIT

	log_info "Creating temporary venv for dependency analysis..."
	python3 -m venv "$ANALYSIS_VENV"

	TARBALL_FILE="$TMPDIR/${PACKAGE_NAME}-${VERSION}.tar.gz"
	if ! curl -sSfL "$TARBALL_URL" -o "$TARBALL_FILE"; then
		log_error "Failed to download tarball from $TARBALL_URL"
		exit 1
	fi

	if command -v sha256sum &>/dev/null; then
		ACTUAL_SHA=$(sha256sum "$TARBALL_FILE" | cut -d' ' -f1)
	else
		ACTUAL_SHA=$(shasum -a 256 "$TARBALL_FILE" | cut -d' ' -f1)
	fi
	if [[ "$ACTUAL_SHA" != "$TARBALL_SHA" ]]; then
		log_error "SHA256 mismatch! Expected: $TARBALL_SHA, Got: $ACTUAL_SHA"
		exit 1
	fi

	log_info "Installing ${PACKAGE_NAME} from tarball..."
	"$ANALYSIS_VENV/bin/pip" install --quiet "$TARBALL_FILE"

	EXCLUDE_ARGS=()
	for pkg in "${WHEEL_PKG_ARRAY[@]}" "${HOMEBREW_PKG_ARRAY[@]}"; do
		EXCLUDE_ARGS+=("$pkg")
	done

	log_info "Generating resource stanzas..."
	RESOURCES=$("$ANALYSIS_VENV/bin/python" "$SCRIPT_DIR/generate_resources.py" "$PACKAGE_NAME" \
		--exclude "${EXCLUDE_ARGS[@]}")

	RESOURCE_COUNT=$(echo "$RESOURCES" | grep -c "^  resource " || echo "0")
	if [[ "$RESOURCE_COUNT" -lt 5 ]]; then
		log_error "Expected multiple resource stanzas but only found ${RESOURCE_COUNT}"
		exit 1
	fi
	echo "$RESOURCES" >"$TMPDIR/resources.txt"

	log_info "Generating wheel resources..."
	: >"$TMPDIR/wheels.txt"
	while IFS= read -r wheel_pkg; do
		[[ -z "$wheel_pkg" ]] && continue
		wheel_type=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('type', 'universal'))" "$WHEEL_PACKAGES_JSON" "$wheel_pkg")
		wheel_comment=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('comment', ''))" "$WHEEL_PACKAGES_JSON" "$wheel_pkg")
		resolve_from=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('resolve-version-from', ''))" "$WHEEL_PACKAGES_JSON" "$wheel_pkg")

		wheel_args=(--type "$wheel_type" --comment "$wheel_comment" --python-version "${PYTHON_VERSION_DOT}")
		if [[ "$wheel_type" == "platform" && -n "$resolve_from" ]]; then
			wheel_version=$("$ANALYSIS_VENV/bin/python" -c \
				"from importlib.metadata import version; print(version('${resolve_from}'))")
			wheel_args+=(--version "$wheel_version")
		fi

		python3 "$SCRIPT_DIR/fetch_wheel_info.py" "$wheel_pkg" "${wheel_args[@]}" >>"$TMPDIR/wheels.txt"
	done <<<"$(printf '%s\n' "${WHEEL_PKG_ARRAY[@]}")"

	python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('caveats', ''))" "$CONFIG_JSON" |
		while IFS= read -r line || [[ -n "$line" ]]; do
			printf '      %s\n' "$line"
		done >"$TMPDIR/caveats.txt"

	{
		for dep in "${HOMEBREW_PKG_ARRAY[@]}"; do
			if [[ "$dep" == "rust" ]]; then
				echo '  depends_on "rust" # provides clippy, rustfmt, and cargo for cargo-audit'
			else
				echo "  depends_on \"${dep}\""
			fi
		done
		echo "  depends_on \"python@${PYTHON_VERSION}\""
	} >"$TMPDIR/deps.txt"

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
		--replace-file "CAVEATS=${TMPDIR}/caveats.txt" \
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
