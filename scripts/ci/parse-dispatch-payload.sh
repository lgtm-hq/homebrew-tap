#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Parse repository_dispatch client payload for formula updates.

set -euo pipefail

: "${CLIENT_PAYLOAD:?CLIENT_PAYLOAD is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

formula=$(echo "$CLIENT_PAYLOAD" | jq -r '.formula // empty')
version=$(echo "$CLIENT_PAYLOAD" | jq -r '.version // empty')
pypi_package=$(echo "$CLIENT_PAYLOAD" | jq -r '."pypi-package" // empty')
binary_assets=$(echo "$CLIENT_PAYLOAD" | jq -c '."binary-assets" // {}')

if [[ -z "$formula" || -z "$version" ]]; then
	echo "Dispatch payload must include formula and version" >&2
	exit 1
fi

validate_single_line() {
	local name="$1"
	local value="$2"
	if [[ "$value" == *$'\n'* ]]; then
		echo "${name} must not contain newlines" >&2
		exit 1
	fi
}

if [[ ! "$formula" =~ ^[A-Za-z0-9._-]+$ ]]; then
	echo "Invalid formula identifier: ${formula}" >&2
	exit 1
fi

if [[ ! "$version" =~ ^v?[0-9]+(\.[0-9]+)*(-[A-Za-z0-9._-]+)?$ ]]; then
	echo "Invalid version: ${version}" >&2
	exit 1
fi

version="${version#v}"

if [[ -n "$pypi_package" && ! "$pypi_package" =~ ^[A-Za-z0-9._-]+$ ]]; then
	echo "Invalid pypi-package: ${pypi_package}" >&2
	exit 1
fi

validate_single_line formula "$formula"
validate_single_line version "$version"
validate_single_line pypi-package "$pypi_package"
validate_single_line binary-assets "$binary_assets"

{
	printf 'formula=%s\n' "$formula"
	printf 'version=%s\n' "$version"
	printf 'pypi-package=%s\n' "$pypi_package"
	{
		printf 'binary-assets<<EOF\n'
		printf '%s\n' "$binary_assets"
		printf 'EOF\n'
	}
} >>"$GITHUB_OUTPUT"
