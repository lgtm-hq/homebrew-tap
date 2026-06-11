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

{
	echo "formula=$formula"
	echo "version=$version"
	echo "pypi-package=$pypi_package"
	echo "binary-assets=$binary_assets"
} >>"$GITHUB_OUTPUT"
