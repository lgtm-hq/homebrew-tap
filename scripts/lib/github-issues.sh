#!/usr/bin/env bash
# github-issues.sh - GitHub issue management utilities
#
# Requires: gh CLI authenticated with issues:write permission

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# Issue Management Functions
# =============================================================================

# Find an existing open issue by label
# Usage: issue_number=$(find_open_issue "label-name")
find_open_issue() {
	local label="$1"
	gh issue list --state open --label "$label" --json number --jq '.[0].number // empty' 2>/dev/null || echo ""
}

# Create a new issue
# Usage: create_issue "title" "body" "label1,label2"
create_issue() {
	local title="$1"
	local body="$2"
	local labels="$3"

	gh issue create \
		--title "$title" \
		--body "$body" \
		--label "$labels"
}

# Add a comment to an existing issue
# Usage: add_issue_comment 123 "comment body"
add_issue_comment() {
	local issue_number="$1"
	local body="$2"

	gh issue comment "$issue_number" --body "$body"
}

# =============================================================================
# Specific Issue Types
# =============================================================================

# Report version drift between formula and PyPI
# Usage: report_version_drift "1.0.0" "1.0.1"
report_version_drift() {
	local formula_version="$1"
	local pypi_version="$2"

	local existing_issue
	existing_issue=$(find_open_issue "version-drift")

	if [[ -n "$existing_issue" ]]; then
		log_info "Updating existing version drift issue #$existing_issue"
		add_issue_comment "$existing_issue" "$(
			cat <<EOF
## Updated Version Check

- Formula: \`$formula_version\`
- PyPI: \`$pypi_version\`

Checked: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
		)"
	else
		log_info "Creating new version drift issue"
		create_issue \
			"Version drift detected: formula $formula_version vs PyPI $pypi_version" \
			"$(
				cat <<EOF
## Version Drift Detected

| Source | Version |
|--------|---------|
| Formula | \`$formula_version\` |
| PyPI | \`$pypi_version\` |

The formula should be automatically updated when a new release is published. Check the py-lintro release workflow if this persists.

---
*Auto-created by scheduled validation.*
EOF
			)" \
			"version-drift,automated"
	fi
}

# Report validation failure
# Usage: report_validation_failure "https://github.com/.../runs/123"
report_validation_failure() {
	local run_url="$1"

	local existing_issue
	existing_issue=$(find_open_issue "validation-failure")

	if [[ -n "$existing_issue" ]]; then
		log_info "Updating existing validation failure issue #$existing_issue"
		add_issue_comment "$existing_issue" \
			"Validation still failing as of $(date -u +"%Y-%m-%dT%H:%M:%SZ"). [View logs]($run_url)"
		return 0
	fi

	log_info "Creating validation failure issue"
	create_issue \
		"Formula validation failed in scheduled check" \
		"$(
			cat <<EOF
## Scheduled Validation Failed

[View logs]($run_url)

Possible causes:
- Upstream dependency changes
- Homebrew API changes
- macOS runner changes

---
*Auto-created by scheduled validation.*
EOF
		)" \
		"validation-failure,automated,bug"
}
