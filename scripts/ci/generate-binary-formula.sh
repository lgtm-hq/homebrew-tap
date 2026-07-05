#!/usr/bin/env bash
# generate-binary-formula.sh
# Generate a Homebrew formula for binary distribution using product configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
	cat <<'EOF'
Generate a Homebrew formula for binary distribution.

Usage: generate-binary-formula.sh --config <formulas/*.yml> --formula-key <key> \
  --version <ver> --output <file> --binary-assets <json>

Options:
  --config          Path to product config YAML
  --formula-key     Formula key under formulas: in the config
  --version         Package version (without v prefix)
  --output          Output formula path
  --binary-assets   JSON object with arm64-sha and x86-sha keys
EOF
}

CONFIG_PATH=""
FORMULA_KEY=""
VERSION=""
OUTPUT_FILE=""
BINARY_ASSETS="{}"

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

if [[ ! "$ARM64_SHA" =~ ^[0-9a-f]{64}$ || ! "$X86_SHA" =~ ^[0-9a-f]{64}$ ]]; then
	log_error "binary-assets arm64-sha and x86-sha must be 64-character lowercase hex sha256 values"
	exit 1
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
X86_ASSET=$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['x86_64'])" "$BINARY_NAMES_JSON")

build_binary_url() {
	local arch="$1"
	printf '%s\n' "$BINARY_URL_PATTERN" | sed \
		-e 's/{version}/#{version}/g' \
		-e "s/{arch}/${arch}/g"
}

ARM64_URL=$(build_binary_url "arm64")
X86_URL=$(build_binary_url "x86_64")

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

cat >"$OUTPUT_FILE" <<EOF
# typed: strict
# frozen_string_literal: true

# Homebrew formula for ${FORMULA_KEY} binary distribution
# Auto-generated - do not edit manually
class ${CLASS_NAME} < Formula
  desc "${DESCRIPTION}"
  homepage "${HOMEPAGE}"
  version "${VERSION}"
  license "${LICENSE}"

  on_macos do
    on_arm do
      url "${ARM64_URL}"
      sha256 "${ARM64_SHA}"
    end
    on_intel do
      url "${X86_URL}"
      sha256 "${X86_SHA}"
    end
  end

  def install
    if Hardware::CPU.arm?
      bin.install "${ARM64_ASSET}" => "${INSTALL_NAME}"
    else
      bin.install "${X86_ASSET}" => "${INSTALL_NAME}"
    end
  end
${CAVEATS_BLOCK}

  test do
    assert_match version.to_s, shell_output("#{bin}/${INSTALL_NAME} ${TEST_ARGS}")
  end
end
EOF

log_success "Formula written to ${OUTPUT_FILE}"
