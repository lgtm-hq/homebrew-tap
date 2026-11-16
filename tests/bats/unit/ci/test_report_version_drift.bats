#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for the per-product version drift issue report.

load "../../../helpers/common"

FOOTER='*Auto-created by scheduled validation.*'

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	LIB="$REPO_ROOT/scripts/ci/lib/github-issues.sh"
	export MOCK_GH_LOG="$TEST_TEMP_DIR/gh.log"
	: >"$MOCK_GH_LOG"
	mkdir -p "$TEST_TEMP_DIR/mock-bin"
	# Records every call (a "--" line, then one argument per line) and answers
	# the open-issue listing from MOCK_ISSUES (a JSON array of number/body).
	# MOCK_LIST_FAILS=1 makes that listing fail, as a GitHub outage would.
	cat >"$TEST_TEMP_DIR/mock-bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
	echo "--"
	printf '%s\n' "$@"
} >>"$MOCK_GH_LOG"
if [[ "$1 $2" == "issue list" ]]; then
	if [[ -n "${MOCK_LIST_FAILS:-}" ]]; then
		echo "gh: HTTP 502" >&2
		exit 1
	fi
	echo "${MOCK_ISSUES:-[]}"
elif [[ "$1 $2" == "label list" ]]; then
	printf 'version-drift\nautomated\n'
elif [[ -n "${MOCK_WRITE_FAILS:-}" && "$1" == "issue" && "${3:-}" == "$MOCK_WRITE_FAILS" ]]; then
	# A write to this one issue number fails, as a permission error would.
	echo "gh: HTTP 403" >&2
	exit 1
fi
EOF
	chmod +x "$TEST_TEMP_DIR/mock-bin/gh"
	export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"
	export MOCK_ISSUES="[]"
	unset MOCK_LIST_FAILS MOCK_WRITE_FAILS

	ALPHA_OK='{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.2.0","pypi_version":"1.2.0","drift":false}'
	BETA_OK='{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"0.9.0","pypi_version":"0.9.0","drift":false}'
	BETA_BEHIND='{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"0.8.0","pypi_version":"0.9.0","drift":true}'
	CURRENT="[$ALPHA_OK,$BETA_OK]"
	DRIFTED="[$ALPHA_OK,$BETA_BEHIND]"
}

teardown() {
	teardown_temp_dir
}

report() { # $1 = drift report JSON
	run bash -c 'source "$1"; report_version_drift "$2"' _ "$LIB" "$1"
	# Shown by bats only when the test fails: what the report said and did.
	echo "status=$status"
	echo "$output"
	echo "gh calls:"
	cat "$MOCK_GH_LOG"
}

issue() { # $1 = number, $2 = body, $3 = title (optional), $4 = "human" for a person's issue
	local is_bot=true
	[[ "${4:-}" == "human" ]] && is_bot=false
	jq -cn --argjson n "$1" --arg b "$2" --arg t "${3:-Some issue}" --argjson bot "$is_bot" \
		'{number: $n, title: $t, body: $b, author: {is_bot: $bot, login: (if $bot then "app/github-actions" else "someone" end)}}'
}

calls() { # $1 = "issue create" style prefix; prints the number of matching calls
	awk -v want="$1" '
		$0 == "--" { getline a; getline b; if (a " " b == want) n++ }
		END { print n + 0 }
	' "$MOCK_GH_LOG"
}

mutations() { # total create + edit + close calls
	echo $(($(calls 'issue create') + $(calls 'issue edit') + $(calls 'issue close')))
}

@test "report_version_drift: a product that is behind gets its own issue with its marker" {
	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(mutations)" -eq 1 ]
	grep -qx 'Version drift detected: beta (beta)' "$MOCK_GH_LOG"
	grep -qF '| `beta` | `0.8.0` | `beta-pkg` `0.9.0` | behind |' "$MOCK_GH_LOG"
	grep -qxF '<!-- version-drift:beta -->' "$MOCK_GH_LOG"
}

@test "report_version_drift: a product's issue names no other product" {
	report "$DRIFTED"

	[ "$status" -eq 0 ]
	run grep -c 'alpha' "$MOCK_GH_LOG"
	[ "$output" -eq 0 ]
	run grep -ci 'lintro' "$MOCK_GH_LOG"
	[ "$output" -eq 0 ]
}

@test "report_version_drift: two products behind get two issues" {
	local alpha_behind='{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.1.0","pypi_version":"1.2.0","drift":true}'

	report "[$alpha_behind,$BETA_BEHIND]"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 2 ]
	grep -qxF '<!-- version-drift:alpha -->' "$MOCK_GH_LOG"
	grep -qxF '<!-- version-drift:beta -->' "$MOCK_GH_LOG"
}

@test "report_version_drift: an open issue for the product is rewritten, not duplicated" {
	# The issue must show the current versions, not those from the run that
	# opened it.
	export MOCK_ISSUES="[$(issue 50 "old text
$FOOTER
<!-- version-drift:beta -->")]"

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(mutations)" -eq 1 ]
	grep -qx '50' "$MOCK_GH_LOG"
	grep -qx -- '--title' "$MOCK_GH_LOG"
	grep -qx -- '--body' "$MOCK_GH_LOG"
	grep -qF '`0.8.0`' "$MOCK_GH_LOG"
}

@test "report_version_drift: each product's issue is handled on its own" {
	# alpha already has an issue and is still behind; beta is newly behind.
	# alpha's issue is rewritten with alpha's rows only, and beta gets its own.
	local alpha_behind='{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.1.0","pypi_version":"1.2.0","drift":true}'
	export MOCK_ISSUES="[$(issue 60 "$FOOTER
<!-- version-drift:alpha -->")]"

	report "[$alpha_behind,$BETA_BEHIND]"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(calls 'issue close')" -eq 0 ]
	grep -qx 'Version drift detected: alpha (alpha)' "$MOCK_GH_LOG"
	grep -qx 'Version drift detected: beta (beta)' "$MOCK_GH_LOG"
}

@test "report_version_drift: a product that is current again has its issue closed" {
	export MOCK_ISSUES="[$(issue 50 "$FOOTER
<!-- version-drift:beta -->")]"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue close')" -eq 1 ]
	[ "$(mutations)" -eq 1 ]
	grep -qx '50' "$MOCK_GH_LOG"
	grep -q 'Every beta formula matches' "$MOCK_GH_LOG"
}

@test "report_version_drift: nothing behind and no open issue touches nothing" {
	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(mutations)" -eq 0 ]
}

@test "report_version_drift: an auto-created issue from before product markers is closed" {
	# The stale issue this automation opened long ago has the footer and no
	# marker, so it cannot be matched to a product.
	export MOCK_ISSUES="[$(issue 137 "## Version Drift Detected
$FOOTER" "Version drift detected: formula lintro=0.77.0 vs PyPI 0.77.2")]"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue close')" -eq 1 ]
	[ "$(mutations)" -eq 1 ]
	grep -qx '137' "$MOCK_GH_LOG"
	grep -q 'one issue per product' "$MOCK_GH_LOG"
}

@test "report_version_drift: a hand-written issue with the label is never edited or closed" {
	# Someone labels their own issue version-drift: it has neither the marker
	# nor the automation's footer.
	export MOCK_ISSUES="[$(issue 70 "Notes on why winnow lags behind")]"

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
	run grep -cx '70' "$MOCK_GH_LOG"
	[ "$output" -eq 0 ]
}

@test "report_version_drift: an empty or malformed report changes nothing" {
	# A failed collection must never be read as "nothing is behind", and a
	# partial row must never rewrite an issue with blanks.
	export MOCK_ISSUES="[$(issue 50 "$FOOTER
<!-- version-drift:beta -->")]"
	local bad
	for bad in '' '[]' 'not json' '{"drift":false}' '[{"drift":false}]' '[{"drift":true}]' \
		'[{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"","pypi_version":"0.9.0","drift":true}]' \
		'[{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"0.8.0","pypi_version":"0.9.0","drift":"true"}]' \
		'[{"product":"be ta","package":"beta-pkg","formula":"beta","formula_version":"0.8.0","pypi_version":"0.9.0","drift":true}]' \
		"[$BETA_OK,{\"product\":\"alpha\",\"drift\":false}]"; do
		: >"$MOCK_GH_LOG"
		report "$bad"
		[ "$status" -ne 0 ]
		[ "$(mutations)" -eq 0 ]
		[ "$(calls 'issue list')" -eq 0 ]
	done
}

@test "report_version_drift: a failed issue lookup changes nothing and fails" {
	# Otherwise a GitHub error would look like "no open issue" and a second
	# issue would be created for the same product.
	export MOCK_LIST_FAILS=1

	report "$DRIFTED"

	[ "$status" -ne 0 ]
	[ "$(mutations)" -eq 0 ]
}

@test "report_version_drift: an issue that only quotes the marker is not owned" {
	# A hand-written issue discussing the automation quotes its marker inside
	# a sentence. It must not be rewritten; the product gets its own issue.
	export MOCK_ISSUES="[$(issue 70 "The bot adds \`<!-- version-drift:beta -->\` to its issues.
> <!-- version-drift:beta -->")]"

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
}

@test "report_version_drift: an issue that only quotes the footer is not closed as legacy" {
	# Neither a quoted footer nor a footer under an unrelated title makes an
	# issue one of the automation's old drift issues.
	export MOCK_ISSUES="[$(issue 71 "Old issues ended with: $FOOTER" "Version drift detected: formula x vs PyPI y"),$(issue 72 "Some notes
$FOOTER" "Why is the formula behind?")]"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(mutations)" -eq 0 ]
}

@test "report_version_drift: duplicate issues for one product are reconciled" {
	# Two open issues carry the same marker. The oldest is rewritten and the
	# other is closed as its duplicate.
	export MOCK_ISSUES="[$(issue 90 "$FOOTER
<!-- version-drift:beta -->"),$(issue 80 "$FOOTER
<!-- version-drift:beta -->")]"

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(calls 'issue close')" -eq 1 ]
	[ "$(calls 'issue create')" -eq 0 ]
	grep -q 'Duplicate of #80' "$MOCK_GH_LOG"
}

@test "report_version_drift: every duplicate is closed once the product is current" {
	export MOCK_ISSUES="[$(issue 90 "$FOOTER
<!-- version-drift:beta -->"),$(issue 80 "$FOOTER
<!-- version-drift:beta -->")]"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue close')" -eq 2 ]
	[ "$(calls 'issue edit')" -eq 0 ]
}

@test "report_version_drift: a product name that starts another product's name keeps its own issue" {
	local beta_full='{"product":"beta-full","package":"beta-pkg","formula":"beta-full","formula_version":"0.9.0","pypi_version":"0.9.0","drift":false}'
	export MOCK_ISSUES="[$(issue 50 "$FOOTER
<!-- version-drift:beta -->"),$(issue 51 "$FOOTER
<!-- version-drift:beta-full -->")]"

	report "[$BETA_BEHIND,$beta_full]"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(calls 'issue close')" -eq 1 ]
	grep -q 'Every beta-full formula matches' "$MOCK_GH_LOG"
}

@test "report_version_drift: a failed write fails the report but the other products are still handled" {
	# alpha's issue cannot be rewritten; beta's must still be closed, and the
	# report must fail so the job does and the failure is notified.
	local alpha_behind='{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.1.0","pypi_version":"1.2.0","drift":true}'
	export MOCK_ISSUES="[$(issue 40 "$FOOTER
<!-- version-drift:alpha -->"),$(issue 50 "$FOOTER
<!-- version-drift:beta -->")]"
	export MOCK_WRITE_FAILS=40

	report "[$alpha_behind,$BETA_OK]"

	[ "$status" -ne 0 ]
	[[ "$output" == *"Could not refresh issue #40 for alpha"* ]]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(calls 'issue close')" -eq 1 ]
	grep -q 'Every beta formula matches' "$MOCK_GH_LOG"
}

@test "scheduled validation: runs are serialised so two reports cannot both create an issue" {
	local workflow="$REPO_ROOT/.github/workflows/scheduled-validation.yml"
	local concurrency
	concurrency="$(python3 -c "
import sys, yaml
c = yaml.safe_load(open(sys.argv[1], encoding='utf-8')).get('concurrency') or {}
print(c.get('group'), c.get('cancel-in-progress'))
" "$workflow")"

	[ "$concurrency" = "scheduled-validation False" ]
}

@test "report_version_drift: an issue a person opened is never owned, even with the marker and footer on their own lines" {
	# Someone pastes the automation's old issue body, marker and all, into
	# their own issue. Authorship, not text, decides ownership.
	export MOCK_ISSUES="[$(issue 75 "## Version Drift Detected
$FOOTER
<!-- version-drift:beta -->" "Version drift detected: formula lintro=0.77.0 vs PyPI 0.77.2" human)]"

	report "$CURRENT"
	[ "$status" -eq 0 ]
	[ "$(mutations)" -eq 0 ]

	: >"$MOCK_GH_LOG"
	report "$DRIFTED"
	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
}

@test "report_version_drift: the issue of a product that left the report is closed" {
	# gamma was removed from formulas/; its issue would otherwise stay open
	# for good.
	export MOCK_ISSUES="[$(issue 55 "$FOOTER
<!-- version-drift:gamma -->")]"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue close')" -eq 1 ]
	[ "$(mutations)" -eq 1 ]
	grep -qx '55' "$MOCK_GH_LOG"
	grep -q 'No product named gamma is configured' "$MOCK_GH_LOG"
}
