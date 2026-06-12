#!/usr/bin/env bash
# generate-pypi-formula.sh
# Generate a Homebrew formula from PyPI using product configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/lgtm-ci-tooling.sh disable=SC1091
source "$SCRIPT_DIR/../lib/lgtm-ci-tooling.sh"

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
PYTHON_VERSION_NODOT="${PYTHON_VERSION//./}"
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
	if [[ "$RESOURCE_COUNT" -lt "$MIN_RESOURCE_COUNT" ]]; then
		log_error "Expected at least ${MIN_RESOURCE_COUNT} resource stanzas but only found ${RESOURCE_COUNT}"
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

		wheel_args=(--type "$wheel_type" --comment "$wheel_comment" --python-version "${PYTHON_VERSION_NODOT}")
		if [[ "$wheel_type" == "platform" && -n "$resolve_from" ]]; then
			wheel_version=$("$ANALYSIS_VENV/bin/python" -c \
				"from importlib.metadata import version; print(version('${resolve_from}'))")
			wheel_args+=(--version "$wheel_version")
		fi

		python3 "$SCRIPT_DIR/fetch_wheel_info.py" "$wheel_pkg" "${wheel_args[@]}" >>"$TMPDIR/wheels.txt"
	done <<<"$(printf '%s\n' "${WHEEL_PKG_ARRAY[@]}")"

	python3 -c "import json, sys; print(json.loads(sys.argv[1]).get('caveats', ''))" "$CONFIG_JSON" |
		while IFS= read -r line || [[ -n "$line" ]]; do
			if [[ -z "$line" ]]; then
				echo ""
			else
				printf '      %s\n' "$line"
			fi
		done >"$TMPDIR/caveats.txt"

	if [[ -s "$TMPDIR/caveats.txt" ]]; then
		CAVEATS_BLOCK=$(
			cat <<EOF

  def caveats
    <<~EOS
$(cat "$TMPDIR/caveats.txt")
    EOS
  end
EOF
		)
	else
		CAVEATS_BLOCK=""
	fi

	PYDANTIC_CORE_INSTALL=""
	if printf '%s\n' "${WHEEL_PKG_ARRAY[@]}" | grep -qx "pydantic_core"; then
		PYDANTIC_CORE_INSTALL=$(
			cat <<'EOF'
    # Install pydantic_core wheel (requires special handling due to Rust build)
    resource("pydantic_core").stage do
      wheel = Pathname.pwd.children.find { |f| f.extname == ".whl" }
      odie "pydantic_core wheel not found in staged resource" if wheel.nil?
      system libexec/"bin/python", "-m", "pip",
             "install", "--no-deps", "--ignore-installed", wheel.to_s
    end

EOF
		)
	fi
	printf '%s' "$PYDANTIC_CORE_INSTALL" >"$TMPDIR/pydantic_install.txt"
	printf '%s' "$CAVEATS_BLOCK" >"$TMPDIR/caveats_block.txt"

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
		--replace-file "PYDANTIC_CORE_INSTALL=${TMPDIR}/pydantic_install.txt" \
		--replace-file "CAVEATS_BLOCK=${TMPDIR}/caveats_block.txt" \
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
