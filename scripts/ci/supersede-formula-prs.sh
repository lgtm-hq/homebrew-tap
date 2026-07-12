#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Close open bot PRs superseded by a newer formula bump PR.
#
# Bot bump branches are namespaced homebrew/<product>-<version>. When a new
# bump PR opens, any older open PR on the same prefix is obsolete: only the
# latest version is ever relevant (see #129). Each superseded PR is closed
# with an explanatory comment and its branch is deleted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
	cat <<'EOF'
Close open formula bump PRs superseded by a newer one.

Usage: supersede-formula-prs.sh --product <name> --current-pr <number>

Options:
  --product     Product name; matches head branches homebrew/<product>-*
  --current-pr  PR number of the new bump PR (kept open, cited in comments)

Environment:
  GH_TOKEN           GitHub token with pull-requests:write
  GITHUB_REPOSITORY  Target repository (owner/repo)
EOF
}

# BATS tests extract this function via sed (/^supersede_formula_prs() {/,/^}/).
# Keep the signature on one line and avoid nested blocks with `}` at column 0
# (here-docs, case arms) inside this function — they break test extraction.
supersede_formula_prs() {
	local product="$1"
	local current_pr="$2"
	local prefix="homebrew/${product}-"
	local number head_ref
	while IFS=$'\t' read -r number head_ref; do
		if [[ -z "$number" || "$number" == "$current_pr" ]]; then
			continue
		fi
		if [[ "$head_ref" != "$prefix"* ]]; then
			continue
		fi
		log_info "Closing PR #${number} (${head_ref}): superseded by #${current_pr}"
		gh pr close "$number" \
			--repo "$GITHUB_REPOSITORY" \
			--comment "Superseded by #${current_pr}." \
			--delete-branch
	done < <(
		gh pr list \
			--repo "$GITHUB_REPOSITORY" \
			--state open \
			--json number,headRefName \
			--jq '.[] | [.number, .headRefName] | @tsv'
	)
}

main() {
	local product="" current_pr=""
	while [[ $# -gt 0 ]]; do
		if [[ "$1" == "--product" ]]; then
			product="${2:?--product requires a value}"
			shift 2
		elif [[ "$1" == "--current-pr" ]]; then
			current_pr="${2:?--current-pr requires a value}"
			shift 2
		elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
			usage
			return 0
		else
			log_error "Unknown argument: $1"
			usage
			return 1
		fi
	done

	: "${GH_TOKEN:?GH_TOKEN is required}"
	: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
	if [[ -z "$product" || -z "$current_pr" ]]; then
		log_error "Missing required arguments"
		usage
		return 1
	fi
	if [[ ! "$current_pr" =~ ^[0-9]+$ ]]; then
		log_error "--current-pr must be a PR number, got: ${current_pr}"
		return 1
	fi

	supersede_formula_prs "$product" "$current_pr"
	log_success "Superseded PR sweep complete for ${product} (current #${current_pr})"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
