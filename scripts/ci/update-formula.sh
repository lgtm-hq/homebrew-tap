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
  GH_TOKEN               GitHub token for PR creation (default GITHUB_TOKEN)
  PUSH_TOKEN             Optional App installation token for git push
  GITHUB_REPOSITORY      Required when PUSH_TOKEN is set (owner/repo)
EOF
}

configure_git_push_remote() {
	if [[ -z "${PUSH_TOKEN:-}" ]]; then
		return 0
	fi

	: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required when PUSH_TOKEN is set}"
	git remote set-url origin \
		"https://x-access-token:${PUSH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 0
fi

PRODUCT="${DISPATCH_FORMULA:?DISPATCH_FORMULA is required}"
RAW_VERSION="${DISPATCH_VERSION:?DISPATCH_VERSION is required}"
PYPI_PACKAGE_OVERRIDE="${DISPATCH_PYPI_PACKAGE:-}"
BINARY_ASSETS="${DISPATCH_BINARY_ASSETS:-{}}"

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

: "${GH_TOKEN:?GH_TOKEN is required}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

log_info "Staging formula changes..."
git add -- "${CHANGED_FILES[@]}"

if git diff --staged --quiet; then
	log_info "No formula changes detected"
	exit 0
fi

git checkout -B "$PR_BRANCH"
git commit -m "$PR_TITLE"

log_info "Pushing branch ${PR_BRANCH}"
configure_git_push_remote
git push --force-with-lease origin "HEAD:${PR_BRANCH}"

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
else
	log_info "Creating pull request"
	gh pr create \
		--base main \
		--head "$PR_BRANCH" \
		--title "$PR_TITLE" \
		--body "$PR_BODY"
fi

log_success "Formula update PR ready for ${PRODUCT} ${VERSION}"
