#!/usr/bin/env bash
# github-issues.sh - GitHub issue management utilities
#
# Requires: gh CLI authenticated with issues:write permission

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh disable=SC1091 # Dynamic SCRIPT_DIR source is intentional; lintro issue #928 tracks ShellCheck source-path support.
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# Issue Management Functions
# =============================================================================

# Ensure a GitHub label exists, creating it if missing
# Usage: ensure_label "label-name" "description" "color-hex"
ensure_label() {
	local name="$1"
	local description="${2:-}"
	local color="${3:-ededed}"

	if ! gh label list --json name --jq ".[].name" 2>/dev/null | grep -qx "$name"; then
		log_info "Creating missing label: $name"
		gh label create "$name" --description "$description" --color "$color" 2>/dev/null || true
	fi
}

# Find an existing open issue by label
# Usage: issue_number=$(find_open_issue "label-name")
find_open_issue() {
	local label="$1"
	gh issue list --state open --label "$label" --json number --jq '.[0].number // empty' 2>/dev/null || echo ""
}

# Create a new issue, ensuring all labels exist first
# Usage: create_issue "title" "body" "label1,label2"
create_issue() {
	local title="$1"
	local body="$2"
	local labels="$3"

	local IFS=','
	for label in $labels; do
		label="${label#"${label%%[![:space:]]*}"}"
		label="${label%"${label##*[![:space:]]}"}"
		[[ -z "$label" ]] && continue
		ensure_label "$label"
	done

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

# Report version drift between formulas and PyPI, for every product at once.
#
# Takes the JSON list written by check-version-drift.sh (one row per formula:
# product, package, formula, formula_version, pypi_version, drift). One open
# issue labelled version-drift carries the current state of every formula:
#   - drift and no open issue: create it;
#   - drift and an open issue: rewrite its title and body, so it never shows
#     versions from an earlier run;
#   - no drift and an open issue: say so and close it.
# Usage: report_version_drift '<json>'
report_version_drift() {
	local report_json="$1"

	local has_drift drifted table
	# No `jq -e`: it exits non-zero for a `false` result, which is the normal
	# "nothing is behind" answer. Only a malformed report may fail here.
	if ! has_drift=$(jq -r 'if type == "array" and length > 0 and all(.[]; type == "object" and (.drift | type) == "boolean") then any(.[]; .drift) else error("empty or malformed drift report") end' <<<"$report_json" 2>/dev/null); then
		log_error "Drift report is empty or malformed; not touching any issue"
		return 1
	fi
	# jq prints nothing and succeeds on empty input. Anything other than an
	# explicit answer must not be read as "nothing is behind".
	if [[ "$has_drift" != "true" && "$has_drift" != "false" ]]; then
		log_error "Drift report is empty or malformed; not touching any issue"
		return 1
	fi
	drifted=$(jq -r '[.[] | select(.drift) | .formula] | join(", ")' <<<"$report_json")
	table=$(jq -r '.[] | "| \(.product) | `\(.formula)` | `\(.formula_version)` | `\(.package)` `\(.pypi_version)` | \(if .drift then "behind" else "current" end) |"' <<<"$report_json")

	local checked existing_issue
	checked=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	existing_issue=$(find_open_issue "version-drift")

	if [[ "$has_drift" != "true" ]]; then
		if [[ -n "$existing_issue" ]]; then
			log_info "Version drift resolved; closing issue #$existing_issue"
			gh issue close "$existing_issue" --comment "$(
				cat <<EOF
Every formula matches its package's current release as of $checked. Closing.

| Product | Formula | Formula version | PyPI | State |
|---------|---------|-----------------|------|-------|
$table
EOF
			)"
		else
			log_info "No version drift and no open drift issue"
		fi
		return 0
	fi

	local title body
	title="Version drift detected: $drifted"
	body=$(
		cat <<EOF
## Version Drift Detected

| Product | Formula | Formula version | PyPI | State |
|---------|---------|-----------------|------|-------|
$table

Each formula is updated automatically when its product publishes a release. If a formula stays behind, check the \`Update - Homebrew Formula\` runs in this repository for that product.

Last checked: $checked. This issue is rewritten by each scheduled validation run and closed when nothing is behind.

---
*Auto-created by scheduled validation.*
EOF
	)

	if [[ -n "$existing_issue" ]]; then
		log_info "Refreshing version drift issue #$existing_issue"
		gh issue edit "$existing_issue" --title "$title" --body "$body"
	else
		log_info "Creating new version drift issue"
		create_issue "$title" "$body" "version-drift,automated"
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
