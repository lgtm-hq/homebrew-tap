#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for the per-product version drift check and its issue report.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	unset GITHUB_OUTPUT

	# Two products: alpha ships two formulas from one package, beta ships one.
	export FORMULA_CONFIG_DIR="$TEST_TEMP_DIR/formulas"
	export FORMULA_DIR="$TEST_TEMP_DIR/Formula"
	export PYPI_FIXTURE_DIR="$TEST_TEMP_DIR/pypi"
	mkdir -p "$FORMULA_CONFIG_DIR" "$FORMULA_DIR" "$PYPI_FIXTURE_DIR"
	cat >"$FORMULA_CONFIG_DIR/alpha.yml" <<'YAML'
---
package: alpha-pkg
formulas:
  alpha:
    type: pypi
  alpha-full:
    type: pypi
YAML
	cat >"$FORMULA_CONFIG_DIR/beta.yml" <<'YAML'
---
package: beta-pkg
formulas:
  beta:
    type: pypi
YAML
	write_pypi alpha-pkg 1.2.0
	write_pypi beta-pkg 0.9.0
	write_sdist_formula alpha alpha_pkg 1.2.0
	write_sdist_formula alpha-full alpha_pkg 1.2.0
	write_sdist_formula beta beta_pkg 0.9.0
}

teardown() {
	teardown_temp_dir
}

write_pypi() { # $1 = package, $2 = latest version
	printf '{"info": {"version": "%s"}}\n' "$2" >"$PYPI_FIXTURE_DIR/$1.json"
}

write_sdist_formula() { # $1 = formula, $2 = sdist name, $3 = version
	cat >"$FORMULA_DIR/$1.rb" <<RUBY
class Fixture < Formula
  url "https://files.pythonhosted.org/packages/ab/cd/$2-$3.tar.gz"
end
RUBY
}

report_field() { # $1 = jq filter over the drift_report rows
	local line
	line="$(printf '%s\n' "$output" | grep '^drift_report=')"
	jq -r "$1" <<<"${line#drift_report=}"
}

@test "check-version-drift: every formula of every product is checked" {
	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[[ "$output" == *"has_drift=false"* ]]
	[ "$(report_field 'length')" -eq 3 ]
	[ "$(report_field '[.[].formula] | join(",")')" = "alpha,alpha-full,beta" ]
	[ "$(report_field '[.[].product] | unique | join(",")')" = "alpha,beta" ]
}

@test "check-version-drift: drift in the second product is reported although the first is current" {
	# The case that went unnoticed: the first product is up to date and the
	# other one is behind.
	write_sdist_formula beta beta_pkg 0.8.0

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[[ "$output" == *"has_drift=true"* ]]
	[ "$(report_field '[.[] | select(.drift) | .formula] | join(",")')" = "beta" ]
	[ "$(report_field '.[] | select(.formula == "beta") | .formula_version')" = "0.8.0" ]
	[ "$(report_field '.[] | select(.formula == "beta") | .pypi_version')" = "0.9.0" ]
	[ "$(report_field '.[] | select(.formula == "beta") | .package')" = "beta-pkg" ]
	[ "$(report_field '.[] | select(.formula == "alpha") | .drift')" = "false" ]
}

@test "check-version-drift: each formula is compared with its own package" {
	# alpha-pkg and beta-pkg have different latest versions; neither formula
	# may be compared with the other product's package.
	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[ "$(report_field '.[] | select(.formula == "alpha") | .pypi_version')" = "1.2.0" ]
	[ "$(report_field '.[] | select(.formula == "beta") | .pypi_version')" = "0.9.0" ]
}

@test "check-version-drift: both formulas of one product are checked" {
	write_sdist_formula alpha-full alpha_pkg 1.1.0

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[ "$(report_field '[.[] | select(.drift) | .formula] | join(",")')" = "alpha-full" ]
}

@test "check-version-drift: a binary formula's version field is read" {
	cat >"$FORMULA_DIR/beta.rb" <<'RUBY'
class Fixture < Formula
  version "0.9.0"
  url "https://github.com/example/beta/releases/download/v0.9.0/beta-macos-arm64"
end
RUBY

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[ "$(report_field '.[] | select(.formula == "beta") | .formula_version')" = "0.9.0" ]
	[[ "$output" == *"has_drift=false"* ]]
}

@test "check-version-drift: a configured formula with no formula file is an error" {
	rm "$FORMULA_DIR/beta.rb"

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -ne 0 ]
	[[ "$output" == *"Formula not found for beta"* ]]
	[[ "$output" != *"drift_report="* ]]
}

@test "check-version-drift: a package PyPI cannot answer for is an error, not 'current'" {
	rm "$PYPI_FIXTURE_DIR/beta-pkg.json"

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -ne 0 ]
	[[ "$output" != *"drift_report="* ]]
}

@test "check-version-drift: no product selected is an error" {
	run bash "$SCRIPTS_DIR/check-version-drift.sh"

	[ "$status" -eq 2 ]
	[[ "$output" == *"No product selected"* ]]
}

@test "check-version-drift: a single check needs both the formula and its package" {
	run bash "$SCRIPTS_DIR/check-version-drift.sh" alpha

	[ "$status" -eq 2 ]
	[[ "$output" == *"needs a formula name and its PyPI package"* ]]
}

@test "check-version-drift: a single explicit check reports that formula only" {
	write_sdist_formula beta beta_pkg 0.8.0

	run bash "$SCRIPTS_DIR/check-version-drift.sh" beta beta-pkg

	[ "$status" -eq 0 ]
	[ "$(report_field 'length')" -eq 1 ]
	[ "$(report_field '.[0].drift')" = "true" ]
}

@test "check-version-drift: no product configs is an error" {
	rm "$FORMULA_CONFIG_DIR"/*.yml

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -ne 0 ]
	[[ "$output" == *"No product configs found"* ]]
}

@test "check-version-drift: a formula with an arm binary and a nested Intel sdist reads the sdist version" {
	# The shape of the real lintro formula: no version field, a GitHub
	# release binary on arm and the PyPI sdist inside on_intel.
	cat >"$FORMULA_DIR/beta.rb" <<'RUBY'
class Fixture < Formula
  on_macos do
    on_arm do
      url "https://github.com/example/beta/releases/download/v0.9.0/beta-macos-arm64"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/ab/cd/beta_pkg-0.9.0.tar.gz"
    end
  end
end
RUBY

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[ "$(report_field '.[] | select(.formula == "beta") | .formula_version')" = "0.9.0" ]
	[[ "$output" == *"has_drift=false"* ]]
}

@test "check-version-drift: product configs with a .yaml extension are read too" {
	mv "$FORMULA_CONFIG_DIR/beta.yml" "$FORMULA_CONFIG_DIR/beta.yaml"

	run bash "$SCRIPTS_DIR/check-version-drift.sh" --all

	[ "$status" -eq 0 ]
	[ "$(report_field '[.[].product] | unique | join(",")')" = "alpha,beta" ]
}

@test "repository: every configured formula has a formula file and a package" {
	# Guards the real configs the scheduled run reads. Counts what it checked,
	# so a reader that fails or finds nothing cannot pass.
	unset FORMULA_CONFIG_DIR FORMULA_DIR
	local config key keys package checked=0
	shopt -s nullglob
	for config in "$REPO_ROOT"/formulas/*.yml "$REPO_ROOT"/formulas/*.yaml; do
		keys="$(python3 "$SCRIPTS_DIR/read_formula_config.py" "$config" --list-formulas)"
		[ -n "$keys" ]
		while IFS= read -r key; do
			[ -f "$REPO_ROOT/Formula/$key.rb" ]
			package="$(python3 "$SCRIPTS_DIR/read_formula_config.py" "$config" --formula-key "$key" --json |
				jq -r '.package // empty')"
			[ -n "$package" ]
			checked=$((checked + 1))
		done <<<"$keys"
	done
	shopt -u nullglob
	[ "$checked" -ge 3 ]
}

@test "scheduled validation: the workflow names no product and passes the report through the environment" {
	local workflow="$REPO_ROOT/.github/workflows/scheduled-validation.yml"

	run grep -c 'PYPI_PACKAGE' "$workflow"
	[ "$output" -eq 0 ]
	run grep -ci 'lintro\|winnow' "$workflow"
	[ "$output" -eq 0 ]
	grep -q 'check-version-drift.sh --all$' "$workflow"
	grep -q 'DRIFT_REPORT: \${{ needs.check-version-drift.outputs.drift_report }}' "$workflow"
	grep -q 'report_version_drift "\$DRIFT_REPORT"' "$workflow"
}

@test "scheduled validation: reporting does not wait for the install check, and every job's failure is notified" {
	local workflow="$REPO_ROOT/.github/workflows/scheduled-validation.yml"
	local wiring
	wiring="$(python3 - "$workflow" <<'PY'
import sys

import yaml

jobs = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))["jobs"]


def needs(job):
    value = jobs[job].get("needs", [])
    return sorted([value] if isinstance(value, str) else value)


print("report-needs=" + ",".join(needs("report-version-drift")))
print("report-if=" + str(jobs["report-version-drift"].get("if")))
print("validate-needs=" + ",".join(needs("validate-formula")))
print("notify-needs=" + ",".join(needs("notify-failure")))
print("notify-if=" + str(jobs["notify-failure"].get("if")))
PY
	)"

	[[ "$wiring" == *"report-needs=check-version-drift"$'\n'* ]]
	[[ "$wiring" == *"report-if=needs.check-version-drift.result == 'success'"* ]]
	[[ "$wiring" == *"validate-needs="$'\n'* ]]
	[[ "$wiring" == *"notify-needs=check-version-drift,report-version-drift,validate-formula"$'\n'* ]]
	[[ "$wiring" == *"notify-if=failure()"* ]]
}
