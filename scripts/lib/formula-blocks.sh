#!/usr/bin/env bash
# formula-blocks.sh - Optional formula stanza builders shared by the
# binary and PyPI generators.
#
# Each builder prints a block that is substituted into a template placeholder
# placed at the END of the preceding line (e.g. `  end{{CONFLICTS_BLOCK}}`).
# Blocks therefore start with the newline(s) that separate them from that
# line and never end with a trailing newline, so an absent (empty) block
# leaves the surrounding template bytes untouched.

# Build a conflicts_with stanza from a config object.
# Usage: build_conflicts_block '{"formula":"x","because":"...","comment":"..."}'
# Prints nothing when the config object is empty or has no formula.
build_conflicts_block() {
	local conflicts_json="$1"

	local formula because comment
	formula=$(python3 -c "import json, sys; print((json.loads(sys.argv[1]) or {}).get('formula', '') or '')" "$conflicts_json")
	if [[ -z "$formula" ]]; then
		return 0
	fi
	because=$(python3 -c "import json, sys; print((json.loads(sys.argv[1]) or {}).get('because', '') or '')" "$conflicts_json")
	comment=$(python3 -c "import json, sys; print((json.loads(sys.argv[1]) or {}).get('comment', '') or '')" "$conflicts_json")

	printf '\n'
	if [[ -n "$comment" ]]; then
		printf '\n  # %s' "$comment"
	fi
	if [[ -n "$because" ]]; then
		printf '\n  conflicts_with "%s", because: "%s"' "$formula" "$because"
	else
		printf '\n  conflicts_with "%s"' "$formula"
	fi
}

# Build extra `test do` lines from free-form config text (one Ruby line per
# input line, indented to the test block's 4-space level).
# Usage: build_test_extra_block "$TEST_EXTRA_TEXT"
build_test_extra_block() {
	local raw="$1"

	if [[ -z "$raw" ]]; then
		return 0
	fi

	local line
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -z "$line" ]]; then
			printf '\n'
		else
			printf '\n    %s' "$line"
		fi
	done <<<"$raw"
}

# Build a `head` stanza pointing at the product source repository.
# Usage: build_head_block "<owner/repo>" "<branch>"
# Prints nothing when the repo is empty.
build_head_block() {
	local source_repo="$1"
	local branch="${2:-main}"

	if [[ -z "$source_repo" ]]; then
		return 0
	fi
	printf '\n  head "https://github.com/%s.git", branch: "%s"' "$source_repo" "$branch"
}

# Build the standard explanatory comment for formulae that intentionally
# declare no bottle block.
# Usage: build_bottle_comment_block
build_bottle_comment_block() {
	cat <<'EOF'


  # No bottle block is declared here: bottles are pre-compiled binary packages
  # whose SHA256 checksums are produced by the tap's brew test-bot after this
  # formula is merged. They cannot be hardcoded in the source template, so the
  # tap CI injects the `bottle do ... end` stanza when it builds bottles.
EOF
}
