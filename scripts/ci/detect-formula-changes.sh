#!/usr/bin/env bash
# detect-formula-changes.sh
# Decide whether Homebrew formula validation must run for the current ref.
#
# validate-formula is a required status check, but the heavy macOS validation
# only makes sense when formula-related files change. This computes that signal
# so the validate-formula job can report a (fast) success on unrelated PRs
# instead of never running and deadlocking the required check.
#
# Writes `formula=true|false` to GITHUB_OUTPUT.
#
# Environment:
#   GITHUB_OUTPUT   Required. File to append the output to.
#   BASE_SHA        Base commit for the diff (empty on push/dispatch -> true).
#   HEAD_SHA        Head commit for the diff (default: HEAD).
#   CHANGED_FILES   Optional test seam: newline-separated file list to use
#                   instead of computing a git diff.
#
# Also writes `runner=macos-26|ubuntu-24.04` so the caller can select a runner
# without an over-long expression in the workflow.

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-HEAD}"

# Paths whose changes require the full formula validation.
FORMULA_PATH_REGEX='^(Formula/|formulas/|scripts/|\.github/workflows/(validate-homebrew-formula|update-formula)\.yml$)'

emit() {
	local formula="$1"
	local runner="ubuntu-24.04"
	[[ "$formula" == "true" ]] && runner="macos-26"
	{
		echo "formula=${formula}"
		echo "runner=${runner}"
	} >>"$GITHUB_OUTPUT"
}

if [[ -n "${CHANGED_FILES:-}" ]]; then
	changed="$CHANGED_FILES"
elif [[ -z "$BASE_SHA" ]]; then
	# No base ref (push to main / manual dispatch): validate to be safe.
	emit "true"
	exit 0
else
	changed="$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}")"
fi

if grep -qE "$FORMULA_PATH_REGEX" <<<"$changed"; then
	emit "true"
else
	emit "false"
fi
