#!/usr/bin/env bash
# provenance.sh - Supply-chain checks that run before a digest is pinned
# into a formula (lgtm-hq/homebrew-tap#471).
#
# Three independent controls, all keyed off the `provenance:` block in
# formulas/*.yml (product level, any key overridable per formula entry):
#
#   require-attestation      true: a failed or missing GitHub attestation
#                            fails the update; false/absent: warn only
#   repo                     owner/repo whose GitHub Releases publish the
#                            artifacts (release digest + attestation lookup)
#   tag-prefix               release tag prefix in front of the version
#                            (e.g. "v"; required once the block exists)
#   binary-signer-workflow   owner/repo/.github/workflows/<file> that signed
#                            the release binaries (`--signer-workflow`)
#   sdist-signer-workflow    owner/repo/.github/workflows/<file> that signed
#                            the sdist; a reusable workflow from another repo
#                            is fine because the path carries its repo
#   pypi-publisher-workflow  workflow file PyPI records as the Trusted
#                            Publisher in the PEP 740 provenance
#
# A missing or incomplete block never silently skips a check:
#   - no `provenance:` block at all -> provenance_mode prints "skip" and the
#     caller logs it; the sha256 checks still run.
#   - a block that is present but lacks a key the caller needs -> error
#     naming the key, whatever require-attestation says.
#
# Functions never `exit`; callers decide (they run under set -e).

_PROVENANCE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print one key from a provenance JSON object ("" when absent).
# Usage: provenance_value '<json>' <key>
provenance_value() {
	python3 -c 'import json, sys
value = (json.loads(sys.argv[1]) or {}).get(sys.argv[2], "")
if isinstance(value, bool):
    value = "true" if value else "false"
print(value if value is not None else "")' "$1" "$2"
}

# Print the sha256 of a file (portable across sha256sum/shasum).
# Usage: file_sha256 <file>
file_sha256() {
	if command -v sha256sum &>/dev/null; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

# Decide whether provenance checks run for a product and validate the block.
# Usage: provenance_mode '<json>' <binary|pypi> <label>
# Prints "skip" when the config has no provenance block, "verify" when the
# block is complete for the caller kind; returns 1 (naming the key) when
# the block is present but incomplete.
provenance_mode() {
	local provenance_json="$1"
	local kind="$2"
	local label="$3"

	local key_count
	key_count="$(python3 -c 'import json, sys; print(len(json.loads(sys.argv[1]) or {}))' "$provenance_json")"
	if [[ "$key_count" -eq 0 ]]; then
		printf 'skip\n'
		return 0
	fi

	local required=(repo tag-prefix sdist-signer-workflow pypi-publisher-workflow)
	if [[ "$kind" == "binary" ]]; then
		required+=(binary-signer-workflow)
	fi
	local key missing=0
	for key in "${required[@]}"; do
		if [[ -z "$(provenance_value "$provenance_json" "$key")" ]]; then
			log_error "provenance.${key} is required for ${label}: the provenance block is present but incomplete"
			missing=1
		fi
	done
	if [[ "$missing" -eq 1 ]]; then
		return 1
	fi
	printf 'verify\n'
}

# Verify a GitHub artifact attestation for a downloaded file.
# Usage: verify_attestation <file> <label> <repo> <signer-workflow> <require>
# The identity is `--repo <repo> --signer-workflow <signer-workflow>`; gh
# rejects --signer-repo alongside --signer-workflow, and the workflow path
# already names the signing repository. Needs egress to api.github.com and
# tuf-repo-cdn.sigstore.dev. An empty identity is a configuration error,
# never a skip (provenance_mode decides whether checks run at all).
verify_attestation() {
	local file="$1"
	local label="$2"
	local repo="$3"
	local workflow="$4"
	local require="${5:-false}"
	local identity="repo ${repo}, signer workflow ${workflow}"

	if [[ -z "$repo" || -z "$workflow" ]]; then
		log_error "No attestation identity (repo + signer workflow) configured for ${label}"
		return 1
	fi

	log_info "Verifying attestation for ${label} (${identity})"
	local output
	if output="$(gh attestation verify "$file" --repo "$repo" --signer-workflow "$workflow" 2>&1)"; then
		log_success "Attestation verified for ${label} (${identity})"
		return 0
	fi

	local digest
	digest="$(file_sha256 "$file")"
	if [[ "$require" == "true" ]]; then
		log_error "Attestation verification failed for ${label} (sha256 ${digest}): no attestation from ${identity} matched"
		printf '%s\n' "$output" >&2
		return 1
	fi
	log_warning "Attestation verification failed for ${label} (sha256 ${digest}): no attestation from ${identity} matched; require-attestation is false, continuing"
	printf '%s\n' "$output" >&2
	return 0
}

# Print the sha256 the GitHub Releases API records for an asset.
# Usage: release_asset_digest <repo> <tag> <asset-name>
release_asset_digest() {
	local repo="$1"
	local tag="$2"
	local asset="$3"
	local digest

	if ! digest="$(gh api "repos/${repo}/releases/tags/${tag}" \
		--jq ".assets[] | select(.name == \"${asset}\") | .digest // empty" 2>&1)"; then
		log_error "Failed to read release ${tag} of ${repo}: ${digest}"
		return 1
	fi
	digest="${digest#sha256:}"
	if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
		log_error "GitHub Release ${tag} of ${repo} has no sha256 digest for asset ${asset}"
		return 1
	fi
	printf '%s\n' "$digest"
}

# Require the three sdist digests to agree; on mismatch name all three.
# Usage: check_sdist_digests <filename> <pypi-sha> <downloaded-sha> <release-sha>
check_sdist_digests() {
	local filename="$1"
	local pypi_sha="$2"
	local downloaded_sha="$3"
	local release_sha="$4"

	if [[ "$pypi_sha" == "$downloaded_sha" && "$downloaded_sha" == "$release_sha" ]]; then
		log_success "sdist digests agree for ${filename}: PyPI JSON == downloaded == GitHub Release (${pypi_sha})"
		return 0
	fi
	log_error "sdist digest mismatch for ${filename}:"
	log_error "  PyPI JSON:       ${pypi_sha}"
	log_error "  downloaded file: ${downloaded_sha}"
	log_error "  GitHub Release:  ${release_sha}"
	return 1
}

# Cross-check a downloaded sdist against the GitHub Release, PyPI's PEP 740
# provenance and the sdist attestation.
# Usage: verify_sdist_provenance <sdist-file> <package> <version> <pypi-sha> '<provenance-json>'
verify_sdist_provenance() {
	local file="$1"
	local package="$2"
	local version="$3"
	local pypi_sha="$4"
	local provenance_json="$5"

	local filename repo require tag_prefix sdist_workflow pypi_workflow
	filename="$(basename "$file")"
	repo="$(provenance_value "$provenance_json" repo)"
	require="$(provenance_value "$provenance_json" require-attestation)"
	tag_prefix="$(provenance_value "$provenance_json" tag-prefix)"
	sdist_workflow="$(provenance_value "$provenance_json" sdist-signer-workflow)"
	pypi_workflow="$(provenance_value "$provenance_json" pypi-publisher-workflow)"

	if [[ -z "$repo" || -z "$tag_prefix" || -z "$sdist_workflow" || -z "$pypi_workflow" ]]; then
		log_error "Incomplete provenance block for ${package} (repo, tag-prefix, sdist-signer-workflow and pypi-publisher-workflow are required)"
		return 1
	fi

	local downloaded_sha release_sha
	downloaded_sha="$(file_sha256 "$file")"
	release_sha="$(release_asset_digest "$repo" "${tag_prefix}${version}" "$filename")" || return 1
	check_sdist_digests "$filename" "$pypi_sha" "$downloaded_sha" "$release_sha" || return 1

	python3 "$_PROVENANCE_LIB_DIR/../check_pypi_provenance.py" \
		"$package" "$version" "$filename" \
		--sha256 "$pypi_sha" --repo "$repo" --workflow "$pypi_workflow" || return 1

	verify_attestation "$file" "$filename" "$repo" "$sdist_workflow" "$require"
}
