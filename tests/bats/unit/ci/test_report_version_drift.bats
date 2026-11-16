#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for the version drift issue report (create, refresh, close).

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	LIB="$REPO_ROOT/scripts/ci/lib/github-issues.sh"
	export MOCK_GH_LOG="$TEST_TEMP_DIR/gh.log"
	: >"$MOCK_GH_LOG"
	mkdir -p "$TEST_TEMP_DIR/mock-bin"
	# Records every call, one argument per line after a "--" separator, and
	# answers the open-issue lookup from MOCK_OPEN_ISSUE (empty = none).
	cat >"$TEST_TEMP_DIR/mock-bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
	echo "--"
	printf '%s\n' "$@"
} >>"$MOCK_GH_LOG"
if [[ "$1 $2" == "issue list" ]]; then
	echo "${MOCK_OPEN_ISSUE:-}"
elif [[ "$1 $2" == "label list" ]]; then
	printf 'version-drift\nautomated\n'
fi
EOF
	chmod +x "$TEST_TEMP_DIR/mock-bin/gh"
	export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"

	CURRENT='[{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.2.0","pypi_version":"1.2.0","drift":false},{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"0.9.0","pypi_version":"0.9.0","drift":false}]'
	DRIFTED='[{"product":"alpha","package":"alpha-pkg","formula":"alpha","formula_version":"1.2.0","pypi_version":"1.2.0","drift":false},{"product":"beta","package":"beta-pkg","formula":"beta","formula_version":"0.8.0","pypi_version":"0.9.0","drift":true}]'
}

teardown() {
	teardown_temp_dir
}

report() { # $1 = drift report JSON
	run bash -c 'source "$1"; report_version_drift "$2"' _ "$LIB" "$1"
}

calls() { # $1 = "issue create" style prefix; prints the number of matching calls
	awk -v want="$1" '
		$0 == "--" { getline a; getline b; if (a " " b == want) n++ }
		END { print n + 0 }
	' "$MOCK_GH_LOG"
}

@test "report_version_drift: drift with no open issue creates one naming the drifted formula" {
	export MOCK_OPEN_ISSUE=""

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 1 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
	grep -q '^Version drift detected: beta$' "$MOCK_GH_LOG"
	grep -q '| beta | `beta` | `0.8.0` | `beta-pkg` `0.9.0` | behind |' "$MOCK_GH_LOG"
	grep -q '| alpha | `alpha` | `1.2.0` | `alpha-pkg` `1.2.0` | current |' "$MOCK_GH_LOG"
}

@test "report_version_drift: the report names no product that is not in the report" {
	export MOCK_OPEN_ISSUE=""

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	! grep -qi 'lintro' "$MOCK_GH_LOG"
}

@test "report_version_drift: drift with an open issue rewrites its title and body" {
	# An existing issue must show the current versions, not the ones from the
	# run that opened it.
	export MOCK_OPEN_ISSUE="137"

	report "$DRIFTED"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 1 ]
	[ "$(calls 'issue create')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
	grep -qx '137' "$MOCK_GH_LOG"
	grep -qx -- '--title' "$MOCK_GH_LOG"
	grep -qx -- '--body' "$MOCK_GH_LOG"
	grep -q '^Version drift detected: beta$' "$MOCK_GH_LOG"
	grep -q '`0.8.0`' "$MOCK_GH_LOG"
}

@test "report_version_drift: no drift with an open issue closes it with the current state" {
	export MOCK_OPEN_ISSUE="137"

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue close')" -eq 1 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue create')" -eq 0 ]
	grep -qx '137' "$MOCK_GH_LOG"
	grep -q 'Every formula matches' "$MOCK_GH_LOG"
}

@test "report_version_drift: no drift and no open issue touches nothing" {
	export MOCK_OPEN_ISSUE=""

	report "$CURRENT"

	[ "$status" -eq 0 ]
	[ "$(calls 'issue create')" -eq 0 ]
	[ "$(calls 'issue edit')" -eq 0 ]
	[ "$(calls 'issue close')" -eq 0 ]
}

@test "report_version_drift: an empty or malformed report fails without touching any issue" {
	# A failed collection must never be read as "nothing is behind" and close
	# a real drift issue.
	export MOCK_OPEN_ISSUE="137"
	local bad
	for bad in '' '[]' 'not json' '{"drift":false}'; do
		: >"$MOCK_GH_LOG"
		report "$bad"
		[ "$status" -ne 0 ]
		[ "$(calls 'issue close')" -eq 0 ]
		[ "$(calls 'issue edit')" -eq 0 ]
		[ "$(calls 'issue create')" -eq 0 ]
	done
}
