#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Handle repository_dispatch formula updates for any lgtm-hq product.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
	cat <<'EOF'
Update Homebrew formulas from a repository_dispatch payload.

Environment:
  DISPATCH_FORMULA       Product config name (formulas/<name>.yml)
  DISPATCH_VERSION       Release version (with or without v prefix)
  DISPATCH_PYPI_PACKAGE  Optional PyPI package override
  DISPATCH_BINARY_ASSETS Optional JSON with arm64-sha and x86-sha
  GH_TOKEN               GitHub App token (contents + pull-requests write)
  GITHUB_REPOSITORY      Target repository (owner/repo)

Commits are created via the GraphQL createCommitOnBranch API (see
scripts/ci/create-signed-commit.sh) so they are GitHub-signed and satisfy
the org main ruleset's required_signatures rule. The bump branch is created
from the CURRENT origin/main head at run time, not the workflow checkout,
so a stale checkout cannot produce conflicting PRs.
EOF
}

# BATS tests extract these functions via sed (/^<name>() {/,/^}/).
# Keep signatures on one line and avoid nested blocks with `}` at column 0
# (here-docs, case arms) inside them — they break test extraction.
remote_main_oid() {
	gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/main" --jq '.object.sha'
}

remote_file_at_ref() {
	# Prints the file content at ref; empty output if the file is absent
	# (HTTP 404). Any other API failure is fatal so a transient error can
	# never be mistaken for "file not found" and silently skip guards.
	local path="$1"
	local ref="$2"
	local output
	if output="$(gh api -H "Accept: application/vnd.github.raw+json" \
		"repos/${GITHUB_REPOSITORY}/contents/${path}?ref=${ref}" 2>&1)"; then
		printf '%s\n' "$output"
		return 0
	fi
	if [[ "$output" == *"HTTP 404"* || "$output" == *"Not Found"* ]]; then
		return 0
	fi
	log_error "Failed to fetch ${path}@${ref}: ${output}"
	return 1
}

remote_blob_sha_at_ref() {
	# Prints the blob sha at ref; empty output if the file is absent
	# (HTTP 404). Any other API failure is fatal (see remote_file_at_ref).
	local path="$1"
	local ref="$2"
	local output
	if output="$(gh api "repos/${GITHUB_REPOSITORY}/contents/${path}?ref=${ref}" \
		--jq '.sha' 2>&1)"; then
		printf '%s\n' "$output"
		return 0
	fi
	if [[ "$output" == *"HTTP 404"* || "$output" == *"Not Found"* ]]; then
		return 0
	fi
	log_error "Failed to fetch blob sha for ${path}@${ref}: ${output}"
	return 1
}

previous_formula_version() {
	# Reads formula content on stdin; prints the sdist version from the
	# `url ".../<pkg>-<version>.tar.gz"` stanza, or nothing if absent.
	sed -nE 's/^[[:space:]]*url ".*-([0-9][^"-]*)\.tar\.gz"$/\1/p' | head -n 1
}

resolve_binary_assets() {
	# Prints DISPATCH_BINARY_ASSETS, defaulting to {} when unset/empty.
	# Deliberately not ${VAR:-{}}: bash ends that expansion at the first
	# `}`, appending a literal `}` to the JSON whenever the variable is
	# set, which breaks generate-binary-formula.sh's JSON parsing.
	local raw="${DISPATCH_BINARY_ASSETS:-}"
	if [[ -z "$raw" ]]; then
		raw="{}"
	fi
	printf '%s' "$raw"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 0
fi

PRODUCT="${DISPATCH_FORMULA:?DISPATCH_FORMULA is required}"
RAW_VERSION="${DISPATCH_VERSION:?DISPATCH_VERSION is required}"
PYPI_PACKAGE_OVERRIDE="${DISPATCH_PYPI_PACKAGE:-}"
BINARY_ASSETS="$(resolve_binary_assets)"

VERSION="${RAW_VERSION#v}"
CONFIG_PATH="$REPO_ROOT/formulas/${PRODUCT}.yml"

if [[ ! -f "$CONFIG_PATH" ]]; then
	log_error "Missing product config: $CONFIG_PATH"
	exit 1
fi

needs_pypi_wait=$(python3 -c "
import yaml
cfg = yaml.safe_load(open('${CONFIG_PATH}'))
print('true' if any(v.get('type') == 'pypi' for v in cfg.get('formulas', {}).values()) else 'false')
")

PACKAGE_NAME="${PYPI_PACKAGE_OVERRIDE}"
if [[ -z "$PACKAGE_NAME" && "$needs_pypi_wait" == "true" ]]; then
	first_pypi_key=$(python3 -c "
import yaml
cfg = yaml.safe_load(open('${CONFIG_PATH}'))
for key, entry in cfg.get('formulas', {}).items():
    if entry.get('type') == 'pypi':
        print(key)
        break
")
	PACKAGE_NAME=$(python3 "$SCRIPT_DIR/read_formula_config.py" "$CONFIG_PATH" \
		--formula-key "$first_pypi_key" --json |
		python3 -c "import json, sys; print(json.load(sys.stdin).get('package') or '')")
fi

if [[ "$needs_pypi_wait" == "true" ]]; then
	log_info "Waiting for PyPI package ${PACKAGE_NAME} ${VERSION}..."
	bash "$SCRIPT_DIR/wait-for-pypi.sh" "$PACKAGE_NAME" "$VERSION"
else
	log_info "Skipping PyPI wait: no pypi formulas in ${CONFIG_PATH}"
fi

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

# Staleness guard: everything below is anchored on the CURRENT origin/main
# head at run time, not the (possibly stale) workflow checkout.
MAIN_OID="$(remote_main_oid)"
log_info "Current origin/main head: ${MAIN_OID}"

mapfile -t FORMULA_KEYS < <(
	python3 "$SCRIPT_DIR/read_formula_config.py" "$CONFIG_PATH" --list-formulas
)

CHANGED_FILES=()
for formula_key in "${FORMULA_KEYS[@]}"; do
	formula_type=$(python3 -c "
import yaml
cfg = yaml.safe_load(open('${CONFIG_PATH}'))
print(cfg['formulas']['${formula_key}']['type'])
")
	output_file="$REPO_ROOT/Formula/${formula_key}.rb"

	case "$formula_type" in
	pypi)
		# Resource-drift guard: compare Requires-Dist of the new version
		# against the version currently on origin/main. Formulas with
		# generate-resources regenerate stanzas from live PyPI metadata on
		# every run, so drift is informational (warn); otherwise drift means
		# stale stanzas and the run must fail loudly.
		{
			read -r pypi_package
			read -r generates_resources
		} < <(python3 -c "
import yaml
cfg = yaml.safe_load(open('${CONFIG_PATH}'))
entry = cfg['formulas']['${formula_key}']
print(entry.get('package') or cfg.get('package') or '')
print('true' if entry.get('generate-resources') else 'false')
")
		pypi_package="${PYPI_PACKAGE_OVERRIDE:-$pypi_package}"
		previous_version="$(
			remote_file_at_ref "Formula/${formula_key}.rb" "$MAIN_OID" |
				previous_formula_version
		)"
		if [[ -n "$pypi_package" && -n "$previous_version" &&
			"$previous_version" != "$VERSION" ]]; then
			drift_mode="fail"
			if [[ "$generates_resources" == "true" ]]; then
				drift_mode="warn"
			fi
			python3 "$SCRIPT_DIR/check_resource_drift.py" "$pypi_package" \
				--previous-version "$previous_version" \
				--new-version "$VERSION" \
				--mode "$drift_mode"
		else
			log_info "Skipping resource-drift check for ${formula_key} (no distinct previous sdist version on main)"
		fi

		pypi_args=(
			--config "$CONFIG_PATH"
			--formula-key "$formula_key"
			--version "$VERSION"
			--output "$output_file"
		)
		if [[ -n "$PYPI_PACKAGE_OVERRIDE" ]]; then
			pypi_args+=(--pypi-package "$PYPI_PACKAGE_OVERRIDE")
		fi
		bash "$SCRIPT_DIR/generate-pypi-formula.sh" "${pypi_args[@]}"
		;;
	binary)
		bash "$SCRIPT_DIR/generate-binary-formula.sh" \
			--config "$CONFIG_PATH" \
			--formula-key "$formula_key" \
			--version "$VERSION" \
			--output "$output_file" \
			--binary-assets "$BINARY_ASSETS"
		;;
	*)
		log_error "Unsupported formula type '${formula_type}' for ${formula_key}"
		exit 1
		;;
	esac

	CHANGED_FILES+=("$output_file")
done

PR_BRANCH="homebrew/${PRODUCT}-${VERSION}"
PR_TITLE="chore(homebrew): update ${PRODUCT} to ${VERSION}"
PR_BODY="Automated formula update triggered by repository_dispatch for ${PRODUCT} ${VERSION}."

cd "$REPO_ROOT"

# Change detection against CURRENT origin/main (not the workflow checkout):
# compare each generated file's git blob sha with the blob on main.
COMMIT_FILES=()
for changed_file in "${CHANGED_FILES[@]}"; do
	rel_path="${changed_file#"$REPO_ROOT"/}"
	local_sha="$(git hash-object "$changed_file")"
	remote_sha="$(remote_blob_sha_at_ref "$rel_path" "$MAIN_OID")"
	if [[ "$local_sha" == "$remote_sha" ]]; then
		log_info "No changes in ${rel_path} vs origin/main"
		continue
	fi
	COMMIT_FILES+=("$rel_path")
done

if [[ ${#COMMIT_FILES[@]} -eq 0 ]]; then
	log_info "No formula changes detected"
	exit 0
fi

# Create the bump branch from the current main head and commit via the
# GraphQL API so the commit is GitHub-signed (required_signatures).
create_commit_args=(
	--branch "$PR_BRANCH"
	--base-oid "$MAIN_OID"
	--message "$PR_TITLE"
)
for rel_path in "${COMMIT_FILES[@]}"; do
	create_commit_args+=(--file "$rel_path")
done
bash "$SCRIPT_DIR/create-signed-commit.sh" "${create_commit_args[@]}"

existing_pr="$(
	gh pr list \
		--head "$PR_BRANCH" \
		--base main \
		--state open \
		--json number \
		--jq '.[0].number // ""'
)"

if [[ -n "$existing_pr" ]]; then
	log_info "Using existing PR #${existing_pr}"
	pr_number="$existing_pr"
else
	log_info "Creating pull request"
	gh pr create \
		--base main \
		--head "$PR_BRANCH" \
		--title "$PR_TITLE" \
		--body "$PR_BODY"
	pr_number="$(
		gh pr list \
			--head "$PR_BRANCH" \
			--base main \
			--state open \
			--json number \
			--jq '.[0].number // ""'
	)"
fi

# Close older bump PRs for the same product; only the latest is relevant.
if [[ -n "$pr_number" ]]; then
	bash "$SCRIPT_DIR/supersede-formula-prs.sh" \
		--product "$PRODUCT" \
		--current-pr "$pr_number"
else
	log_warning "Could not resolve PR number for ${PR_BRANCH}; skipping supersede sweep"
fi

log_success "Formula update PR ready for ${PRODUCT} ${VERSION}"
