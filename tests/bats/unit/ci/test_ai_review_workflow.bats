#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Contract checks for the thin AI review caller workflow.

load "../../../helpers/common"

WORKFLOW=""

setup() {
	WORKFLOW="$(repo_root)/.github/workflows/ai-review.yml"
}

@test "ai-review workflow calls the pinned lgtm-ci reusable" {
	[ -f "$WORKFLOW" ]
	run grep -E 'uses: lgtm-hq/lgtm-ci/.github/workflows/reusable-ai-review.yml@[0-9a-f]{40}' "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -F "tooling-ref:" "$WORKFLOW"
	[ "$status" -eq 0 ]
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
	run grep -F "actions: read" "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "ai-review workflow includes ready_for_review and omits caller concurrency" {
	run grep -F "ready_for_review" "$WORKFLOW"
	[ "$status" -eq 0 ]
	run grep -E '^concurrency:' "$WORKFLOW"
	[ "$status" -ne 0 ]
}
