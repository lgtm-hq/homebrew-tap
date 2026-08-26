#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Contract checks for the thin AI review caller workflow.

load "../../../helpers/common"

WORKFLOW=""

setup() {
	WORKFLOW="$(repo_root)/.github/workflows/ai-review.yml"
}

teardown() {
	teardown_temp_dir
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

# Full pull_request types list as a YAML key (not a comment).
_has_full_types_list() {
	local types_re
	types_re='^[[:space:]]+types: \[opened, synchronize,'
	types_re+=' reopened, ready_for_review\][[:space:]]*$'
	grep -E "$types_re" "$WORKFLOW"
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
	# Keys only — a comment containing the expression must not pass.
	run grep -E '^[[:space:]]+model: \$\{\{ vars\.LINTRO_AI_MODEL \}\}[[:space:]]*$' \
		"$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E \
		'^[[:space:]]+max-cost-usd: \$\{\{ vars\.LINTRO_AI_MAX_COST_USD \}\}[[:space:]]*$' \
		"$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "ai-review workflow is same-repo only and grants actions read" {
	run grep -F "github.event.pull_request.head.repo.full_name == github.repository" \
		"$WORKFLOW"
	[ "$status" -eq 0 ]
	# Permission key only — a comment containing "actions: read" must not pass.
	run grep -E '^[[:space:]]+actions: read[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E '^[[:space:]]+contents: read[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E '^[[:space:]]+pull-requests: read[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E '^permissions: \{\}[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "ai-review workflow enumerates the review-app and provider secrets" {
	local secret
	for secret in \
		LINTRO_REVIEW_APP_ID \
		LINTRO_REVIEW_APP_PRIVATE_KEY \
		ANTHROPIC_API_KEY \
		CLAUDE_CODE_OAUTH_TOKEN \
		OPENAI_API_KEY \
		CODEX_API_KEY \
		CURSOR_API_KEY; do
		run grep -E "^[[:space:]]+${secret}:" "$WORKFLOW"
		[ "$status" -eq 0 ]
	done
}

@test "ai-review workflow includes ready_for_review and omits caller concurrency" {
	run _has_full_types_list
	[ "$status" -eq 0 ]
	# Any-indent concurrency key (job-level included). Comments do not match.
	run grep -E '^[[:space:]]*concurrency:' "$WORKFLOW"
	[ "$status" -ne 0 ]
}

@test "ai-review contract ignores ready_for_review outside the types list" {
	setup_temp_dir
	WORKFLOW="$TEST_TEMP_DIR/ai-review.yml"
	cat >"$WORKFLOW" <<'EOF'
# ready_for_review
"on":
  pull_request:
    types: [opened, synchronize, reopened]
  concurrency:
    group: leaked
EOF
	run _has_full_types_list
	[ "$status" -ne 0 ]
	run grep -E '^[[:space:]]*concurrency:' "$WORKFLOW"
	[ "$status" -eq 0 ]
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
}

@test "ai-review contract ignores model and types list in comments" {
	setup_temp_dir
	WORKFLOW="$TEST_TEMP_DIR/ai-review.yml"
	cat >"$WORKFLOW" <<'EOF'
# model: ${{ vars.LINTRO_AI_MODEL }}
# max-cost-usd: ${{ vars.LINTRO_AI_MAX_COST_USD }}
# types: [opened, synchronize, reopened, ready_for_review]
permissions: {}
jobs:
  ai-review:
    permissions:
      contents: read
EOF
	run grep -E '^[[:space:]]+model: \$\{\{ vars\.LINTRO_AI_MODEL \}\}[[:space:]]*$' \
		"$WORKFLOW"
	[ "$status" -ne 0 ]
	run grep -E \
		'^[[:space:]]+max-cost-usd: \$\{\{ vars\.LINTRO_AI_MAX_COST_USD \}\}[[:space:]]*$' \
		"$WORKFLOW"
	[ "$status" -ne 0 ]
	run _has_full_types_list
	[ "$status" -ne 0 ]
	run grep -E '^permissions: \{\}[[:space:]]*$' "$WORKFLOW"
	[ "$status" -eq 0 ]
}
