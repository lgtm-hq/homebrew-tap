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

# Report version drift between formulas and PyPI, one issue per product.
#
# Takes the JSON list written by check-version-drift.sh (one row per formula:
# product, package, formula, formula_version, pypi_version, drift). Each
# product has at most one open drift issue, identified by a hidden marker in
# its body (the same one-open-issue-per-key convention as the lgtm-ci failure
# notifiers), never by label alone:
#   - a product is behind and has no open issue: create it;
#   - a product is behind and has an open issue: rewrite its title and body,
#     so it never shows versions from an earlier run;
#   - a product is current and has an open issue: say so and close it.
# Issues without the marker are never edited. An auto-created drift issue from
# before the marker existed is closed with a pointer to the new reporting.
# A malformed report, or a failed issue lookup, changes nothing.
# Usage: report_version_drift '<json>'
report_version_drift() {
	local report_json="$1"

	# Every row must be complete before any issue is looked up or changed: a
	# partial report must never be read as "nothing is behind". No `jq -e`:
	# it exits non-zero for a `false` result.
	local valid
	valid=$(jq -r '
		if type == "array" and length > 0 and all(.[];
			type == "object"
			and ([.product, .package, .formula, .formula_version, .pypi_version]
				| all(type == "string" and length > 0))
			and (.product | test("^[A-Za-z0-9._-]+$"))
			and (.drift | type) == "boolean")
		then "ok" else error("malformed drift report") end' <<<"$report_json" 2>/dev/null) || valid=""
	if [[ "$valid" != "ok" ]]; then
		log_error "Drift report is empty or malformed; not touching any issue"
		return 1
	fi

	local open_issues
	if ! open_issues=$(gh issue list --state open --label "version-drift" --limit 200 --json number,body); then
		log_error "Could not list open version-drift issues; not touching any issue"
		return 1
	fi

	local checked footer
	checked=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	footer="*Auto-created by scheduled validation.*"

	local product marker rows has_drift drifted table existing_issue title body
	while IFS= read -r product; do
		marker="<!-- version-drift:${product} -->"
		rows=$(jq -c --arg p "$product" '[.[] | select(.product == $p)]' <<<"$report_json")
		has_drift=$(jq -r 'any(.[]; .drift)' <<<"$rows")
		drifted=$(jq -r '[.[] | select(.drift) | .formula] | join(", ")' <<<"$rows")
		table=$(jq -r '.[] | "| `\(.formula)` | `\(.formula_version)` | `\(.package)` `\(.pypi_version)` | \(if .drift then "behind" else "current" end) |"' <<<"$rows")
		existing_issue=$(jq -r --arg m "$marker" '[.[] | select((.body // "") | contains($m))][0].number // empty' <<<"$open_issues")

		if [[ "$has_drift" != "true" ]]; then
			if [[ -n "$existing_issue" ]]; then
				log_info "Version drift resolved for ${product}; closing issue #$existing_issue"
				gh issue close "$existing_issue" --comment "$(
					cat <<EOF
Every ${product} formula matches its package's current release as of $checked. Closing.

| Formula | Formula version | PyPI | State |
|---------|-----------------|------|-------|
$table
EOF
				)"
			else
				log_info "No version drift for ${product}"
			fi
			continue
		fi

		title="Version drift detected: ${product} (${drifted})"
		body=$(
			cat <<EOF
## Version Drift Detected

| Formula | Formula version | PyPI | State |
|---------|-----------------|------|-------|
$table

Each formula is updated automatically when its product publishes a release. If a formula stays behind, check the \`Update - Homebrew Formula\` runs in this repository for ${product}.

Last checked: $checked. This issue is rewritten by each scheduled validation run and closed when ${product} is no longer behind.

---
$footer
$marker
EOF
		)

		if [[ -n "$existing_issue" ]]; then
			log_info "Refreshing version drift issue #$existing_issue for ${product}"
			gh issue edit "$existing_issue" --title "$title" --body "$body"
		else
			log_info "Creating version drift issue for ${product}"
			create_issue "$title" "$body" "version-drift,automated"
		fi
	done < <(jq -r '[.[].product] | unique | .[]' <<<"$report_json")

	# Drift issues this automation created before issues carried a product
	# marker cannot be matched to a product. Close them; never touch an issue
	# that does not carry the automation's own footer.
	local legacy_issue
	while IFS= read -r legacy_issue; do
		[[ -z "$legacy_issue" ]] && continue
		log_info "Closing version drift issue #$legacy_issue from before per-product reporting"
		gh issue close "$legacy_issue" --comment "Version drift is now reported in one issue per product, rewritten on every scheduled run and closed when the product is current. This issue predates that and cannot be matched to a product, so it is closed. Any product that is behind today has its own open issue."
	done < <(jq -r --arg f "$footer" '.[] | select(((.body // "") | contains($f)) and (((.body // "") | contains("<!-- version-drift:")) | not)) | .number' <<<"$open_issues")
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
