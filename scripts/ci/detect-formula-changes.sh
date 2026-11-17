#!/usr/bin/env bash
# detect-formula-changes.sh
# Decide which Homebrew formulas must be validated for the current ref.
#
# validate-formula is a required status check, but the heavy macOS validation
# only makes sense when formula-related files change. This computes that signal
# so the validate-formula job can report a (fast) success on unrelated changes
# instead of never running and deadlocking the required check.
#
# Selection by event:
#   pull_request / merge_group (BASE_SHA set)
#       Any formula-related change validates every formula; anything else
#       validates nothing. This is the full check before a merge.
#   push (EVENT_NAME=push)
#       Only the formulas the push affected (lgtm-hq/homebrew-tap#661), diffed
#       from the push's `before` commit:
#         Formula/<name>.rb          -> <name>
#         formulas/<config>.yml      -> every formula key under its `formulas:`
#         shared files (scripts/, the validation and update workflows), any
#         other path under Formula/ or formulas/, a deleted formula or config,
#         or a config key without a Formula/<key>.rb  -> every formula
#         anything else              -> nothing
#       An empty or all-zero `before` (first push), or one that is not an
#       ancestor of HEAD (force-push) or not in the clone, validates every
#       formula.
#   anything else (workflow_dispatch, no base)
#       Every formula.
#
# Writes to GITHUB_OUTPUT:
#   formula=true|false     whether any validation runs
#   formulas=<names>       space-separated formulas to validate when only some
#                          are selected; empty means every formula
#   runner=macos-26|<generic runner>
#
# Environment:
#   GITHUB_OUTPUT   Required. File to append the output to.
#   EVENT_NAME      GitHub event name (push selects per-formula mode).
#   PUSH_BEFORE     The push's `before` commit (push events only).
#   BASE_SHA        Base commit for the pull request / merge group diff.
#   HEAD_SHA        Head commit for the diff (default: HEAD).
#   LGTM_CI_RUNNER  Generic no-op runner (default: ubuntu-26.04).
#   CHANGED_FILES   Optional test seam: newline-separated file list to use
#                   instead of computing a git diff.

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EVENT_NAME="${EVENT_NAME:-}"
PUSH_BEFORE="${PUSH_BEFORE:-}"
BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-HEAD}"

# Paths whose changes require formula validation (pull requests: all of it).
FORMULA_PATH_REGEX='^(Formula/|formulas/|scripts/|\.github/workflows/(validate-homebrew-formula|update-formula)\.yml$)'
# Shared paths that can affect every formula: the generator, its templates and
# scripts, the validation scripts and the workflows that run them.
SHARED_PATH_REGEX='^(scripts/|\.github/workflows/(validate-homebrew-formula|update-formula)\.yml$)'
# Formula names that are safe to pass on as data.
FORMULA_NAME_REGEX='^[a-z0-9][a-z0-9+_.@-]*$'

ALL='*all*'

emit() {
	local formula="$1"
	local formulas="${2:-}"
	local runner="${LGTM_CI_RUNNER:-ubuntu-26.04}"
	[[ "$formula" == "true" ]] && runner="macos-26"
	{
		echo "formula=${formula}"
		echo "formulas=${formulas}"
		echo "runner=${runner}"
	} >>"$GITHUB_OUTPUT"
}

emit_all() {
	echo "Validating every formula: $1"
	emit "true" ""
}

# Print the formula keys under the top-level `formulas:` mapping of a product
# config, one per line. Reads the indentation of the first key and lists every
# key at that indentation until the next top-level key.
config_formula_keys() {
	awk '
		/^formulas:[[:space:]]*$/ { inside = 1; next }
		inside && /^[^[:space:]#]/ { inside = 0 }
		inside && /^[[:space:]]+[^[:space:]#][^:]*:/ {
			match($0, /^[[:space:]]+/)
			if (indent == 0) { indent = RLENGTH }
			if (RLENGTH == indent) {
				key = $0
				sub(/^[[:space:]]+/, "", key)
				sub(/:.*$/, "", key)
				print key
			}
		}
	' "$1"
}

formula_exists() {
	[[ "$1" =~ $FORMULA_NAME_REGEX ]] && [[ -f "$REPO_ROOT/Formula/$1.rb" ]]
}

# Map changed paths to formula names, one per line, or print $ALL when the
# change can affect every formula.
select_formulas() {
	local path name key keys
	while IFS= read -r path; do
		[[ -z "$path" ]] && continue
		if [[ "$path" =~ $SHARED_PATH_REGEX ]]; then
			echo "$ALL"
			return 0
		elif [[ "$path" =~ ^Formula/([^/]+)\.rb$ ]]; then
			name="${BASH_REMATCH[1]}"
			formula_exists "$name" || {
				echo "$ALL"
				return 0
			}
			echo "$name"
		elif [[ "$path" =~ ^formulas/[^/]+\.ya?ml$ ]]; then
			[[ -f "$REPO_ROOT/$path" ]] || {
				echo "$ALL"
				return 0
			}
			keys="$(config_formula_keys "$REPO_ROOT/$path")"
			[[ -n "$keys" ]] || {
				echo "$ALL"
				return 0
			}
			while IFS= read -r key; do
				formula_exists "$key" || {
					echo "$ALL"
					return 0
				}
				echo "$key"
			done <<<"$keys"
		elif [[ "$path" =~ ^(Formula|formulas)/ ]]; then
			echo "$ALL"
			return 0
		fi
	done
}

push_base_is_usable() {
	[[ -n "$PUSH_BEFORE" ]] || return 1
	[[ "$PUSH_BEFORE" =~ ^0+$ ]] && return 1
	git cat-file -e "${PUSH_BEFORE}^{commit}" 2>/dev/null || return 1
	git merge-base --is-ancestor "$PUSH_BEFORE" "$HEAD_SHA" 2>/dev/null
}

if [[ "$EVENT_NAME" == "push" ]]; then
	if [[ -n "${CHANGED_FILES:-}" ]]; then
		changed="$CHANGED_FILES"
	elif push_base_is_usable; then
		changed="$(git diff --name-only "$PUSH_BEFORE" "$HEAD_SHA")"
	else
		emit_all "no usable push base (first push, force-push or unknown commit)"
		exit 0
	fi

	selected="$(select_formulas <<<"$changed" | LC_ALL=C sort -u)"
	if [[ -z "$selected" ]]; then
		echo "No formula-related changes in this push; nothing to validate."
		emit "false" ""
	elif grep -qxF "$ALL" <<<"$selected"; then
		emit_all "the push changed files shared by every formula"
	else
		selected="$(tr '\n' ' ' <<<"$selected")"
		selected="${selected% }"
		echo "Validating formulas changed by this push: ${selected}"
		emit "true" "$selected"
	fi
	exit 0
fi

if [[ -n "${CHANGED_FILES:-}" ]]; then
	changed="$CHANGED_FILES"
elif [[ -z "$BASE_SHA" ]]; then
	# No base ref (manual dispatch): validate to be safe.
	emit_all "no base commit to compare against"
	exit 0
else
	changed="$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}")"
fi

if grep -qE "$FORMULA_PATH_REGEX" <<<"$changed"; then
	emit_all "formula-related files changed"
else
	emit "false" ""
fi
