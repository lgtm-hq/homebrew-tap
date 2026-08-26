#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Contract checks for the thin AI review caller workflow.

load "../../../helpers/common"

WORKFLOW=""

setup() {
	WORKFLOW="$(repo_root)/.github/workflows/ai-review.yml"
}

# Unique 40-hex SHA pinned on reusable-ai-review.yml@… uses lines.
_uses_shas() {
	grep -oE 'reusable-ai-review\.yml@[0-9a-f]{40}' "$WORKFLOW" \
		| grep -oE '[0-9a-f]{40}' \
		| sort -u
}

# Unique 40-hex SHA on tooling-ref keys (not comments).
_tooling_shas() {
	grep -E '^[[:space:]]+tooling-ref:' "$WORKFLOW" \
		| grep -oE '[0-9a-f]{40}' \
		| sort -u
}

# Fail unless the caller pins exactly one uses SHA and the same tooling-ref SHA.
_pins_lockstep() {
	local uses_shas tooling_shas
	uses_shas="$(_uses_shas)"
	tooling_shas="$(_tooling_shas)"
	[ -n "$uses_shas" ] || return 1
	[ -n "$tooling_shas" ] || return 1
	[ "$(printf '%s\n' "$uses_shas" | wc -l)" -eq 1 ] || return 1
	[ "$(printf '%s\n' "$tooling_shas" | wc -l)" -eq 1 ] || return 1
	[ "$uses_shas" = "$tooling_shas" ]
}

@test "ai-review workflow pins uses and tooling-ref to the same SHA" {
	[ -f "$WORKFLOW" ]
	_pins_lockstep
}

@test "ai-review workflow forwards model and max-cost from repo vars" {
	run grep -F 'model: ${{ vars.LINTRO_AI_MODEL }}' "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -F 'max-cost-usd: ${{ vars.LINTRO_AI_MAX_COST_USD }}' "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "ai-review workflow is same-repo only and grants actions read" {
	run grep -F "github.event.pull_request.head.repo.full_name == github.repository" "$WORKFLOW"
	[ "$status" -eq 0 ]
	# Permission key only — a comment containing "actions: read" must not pass.
	run grep -E '^[[:space:]]+actions: read[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "ai-review workflow includes ready_for_review and omits caller concurrency" {
	run grep -F "ready_for_review" "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E '^concurrency:' "$WORKFLOW"
	[ "$status" -ne 0 ]
}

@test "ai-review contract fails when uses and tooling-ref SHAs differ" {
	setup_temp_dir
	WORKFLOW="$TEST_TEMP_DIR/ai-review.yml"
	cat >"$WORKFLOW" <<'EOF'
jobs:
  ai-review:
    uses: lgtm-hq/lgtm-ci/.github/workflows/reusable-ai-review.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    with:
      tooling-ref: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
EOF
	run _pins_lockstep
	[ "$status" -ne 0 ]
	teardown_temp_dir
}

@test "ai-review contract ignores actions: read in comments" {
	setup_temp_dir
	WORKFLOW="$TEST_TEMP_DIR/ai-review.yml"
	cat >"$WORKFLOW" <<'EOF'
      # actions: read lets the reusable download artifacts
      contents: read
EOF
	run grep -E '^[[:space:]]+actions: read[[:space:]]*$' "$WORKFLOW"
	[ "$status" -ne 0 ]
	teardown_temp_dir
}
