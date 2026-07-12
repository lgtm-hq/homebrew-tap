#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Purpose: Create a GitHub-signed commit on a branch via the GraphQL API.
#
# Commits created through GraphQL createCommitOnBranch are authored by the
# token identity and automatically signed by GitHub (verified=true), which
# satisfies the org main ruleset's required_signatures rule. Nothing is
# pushed with the git CLI; the branch ref is created/reset server-side and
# the file contents are uploaded as base64 additions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
	cat <<'EOF'
Create a GitHub-signed commit on a branch via GraphQL createCommitOnBranch.

Usage: create-signed-commit.sh --branch <name> --base-oid <sha> \
         --message <headline> --file <repo-relative-path> [--file ...]

Options:
  --branch     Branch to commit on (created or force-reset to --base-oid)
  --base-oid   Commit SHA the branch is (re)pointed to before committing;
               also used as expectedHeadOid for the mutation
  --message    Commit message headline
  --file       Repo-relative path of a file to include (repeatable);
               contents are read from the current working directory

Environment:
  GH_TOKEN           GitHub token with contents:write (GitHub App token)
  GITHUB_REPOSITORY  Target repository (owner/repo)
EOF
}

# BATS tests extract these functions via sed (/^<name>() {/,/^}/).
# Keep signatures on one line and avoid nested blocks with `}` at column 0
# (here-docs, case arms) inside them — they break test extraction.
ensure_branch_at() {
	local branch="$1"
	local oid="$2"
	if gh api "repos/${GITHUB_REPOSITORY}/git/refs" \
		-f ref="refs/heads/${branch}" -f sha="$oid" >/dev/null 2>&1; then
		log_info "Created branch ${branch} at ${oid}"
		return 0
	fi
	gh api -X PATCH "repos/${GITHUB_REPOSITORY}/git/refs/heads/${branch}" \
		-f sha="$oid" -F force=true >/dev/null
	log_info "Reset existing branch ${branch} to ${oid}"
}

build_commit_payload() {
	local branch="$1"
	local expected_head_oid="$2"
	local message="$3"
	shift 3
	# shellcheck disable=SC2016 # $input is a GraphQL variable, not shell
	local mutation='mutation ($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url } } }'
	local additions='[]'
	local file encoded
	for file in "$@"; do
		encoded="$(base64 <"$file" | tr -d '\n')"
		additions="$(jq --arg path "$file" --arg contents "$encoded" \
			'. + [{path: $path, contents: $contents}]' <<<"$additions")"
	done
	jq -n \
		--arg query "$mutation" \
		--arg repo "$GITHUB_REPOSITORY" \
		--arg branch "$branch" \
		--arg oid "$expected_head_oid" \
		--arg message "$message" \
		--argjson additions "$additions" \
		'{query: $query, variables: {input: {branch: {repositoryNameWithOwner: $repo, branchName: $branch}, expectedHeadOid: $oid, message: {headline: $message}, fileChanges: {additions: $additions}}}}'
}

create_commit_on_branch() {
	local payload="$1"
	local response commit_oid
	response="$(gh api graphql --input - <<<"$payload")"
	commit_oid="$(jq -r '.data.createCommitOnBranch.commit.oid // empty' \
		<<<"$response" 2>/dev/null || true)"
	if [[ -z "$commit_oid" ]]; then
		log_error "createCommitOnBranch failed: $(jq -c '.errors // .' <<<"$response" 2>/dev/null || echo "$response")"
		return 1
	fi
	log_success "Created signed commit ${commit_oid}"
}

main() {
	local branch="" base_oid="" message=""
	local files=()
	while [[ $# -gt 0 ]]; do
		if [[ "$1" == "--branch" ]]; then
			branch="${2:?--branch requires a value}"
			shift 2
		elif [[ "$1" == "--base-oid" ]]; then
			base_oid="${2:?--base-oid requires a value}"
			shift 2
		elif [[ "$1" == "--message" ]]; then
			message="${2:?--message requires a value}"
			shift 2
		elif [[ "$1" == "--file" ]]; then
			files+=("${2:?--file requires a value}")
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
	if [[ -z "$branch" || -z "$base_oid" || -z "$message" || ${#files[@]} -eq 0 ]]; then
		log_error "Missing required arguments"
		usage
		return 1
	fi

	local file
	for file in "${files[@]}"; do
		if [[ ! -f "$file" ]]; then
			log_error "File not found: $file"
			return 1
		fi
	done

	ensure_branch_at "$branch" "$base_oid"
	local payload
	payload="$(build_commit_payload "$branch" "$base_oid" "$message" "${files[@]}")"
	create_commit_on_branch "$payload"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
