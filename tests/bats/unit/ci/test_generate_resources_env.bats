#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: The dependency walk (scripts/ci/generate_resources.py) reads
# installed distributions and Python marker values only from the analysis
# environment described by --analysis-env, never from the interpreter it
# runs under (#638). Everything here is offline: the "analysis environment"
# is a directory of dist-info metadata and a hand-written description.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
	export PYPI_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/pypi"
	ENV_SITE="$TEST_TEMP_DIR/env/site-packages"
	HOST_SITE="$TEST_TEMP_DIR/host/site-packages"
	ENV_JSON="$TEST_TEMP_DIR/analysis-env.json"
	mkdir -p "$ENV_SITE" "$HOST_SITE"
}

teardown() {
	teardown_temp_dir
}

# install <site-dir> <name> <version> [Requires-Dist line]...
install() {
	local site="$1" name="$2" version="$3"
	shift 3
	local dist="$site/${name}-${version}.dist-info"
	mkdir -p "$dist"
	{
		printf 'Metadata-Version: 2.1\nName: %s\nVersion: %s\n' "$name" "$version"
		local requirement
		for requirement in "$@"; do
			printf 'Requires-Dist: %s\n' "$requirement"
		done
	} >"$dist/METADATA"
}

# describe_env [jq filter applied to the description]
# Writes a description of a Linux x86_64 CPython 3.13.5 analysis environment,
# which is what the formula update workflow's runner produces.
describe_env() {
	jq -n --arg site "$ENV_SITE" '{
		site_paths: [$site],
		marker_env: {
			implementation_name: "cpython",
			implementation_version: "3.13.5",
			os_name: "posix",
			platform_machine: "x86_64",
			platform_python_implementation: "CPython",
			platform_release: "6.8.0-generic",
			platform_system: "Linux",
			platform_version: "#1 SMP",
			python_full_version: "3.13.5",
			python_version: "3.13",
			sys_platform: "linux"
		}
	}' | jq "${1:-.}" >"$ENV_JSON"
}

# walk [extra arguments]; the host directory is on PYTHONPATH the way the
# analysis environment used to be, so anything read from it is a leak.
walk() {
	PYTHONPATH="$HOST_SITE" run python3 "$SCRIPTS_DIR/generate_resources.py" rootpkg \
		--analysis-env "$ENV_JSON" --python-version 3.13 "$@"
}

@test "generate_resources: a dependency only the host has installed is resolved from PyPI, not taken from the host" {
	# idna is required for the target but absent from the analysis
	# environment. The host's copy must not answer for it.
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "idna>=3.7"
	install "$ENV_SITE" click 8.1.7
	install "$HOST_SITE" idna 3.7
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *"Resolved idna==3.19 from PyPI"* ]]
	[[ "$output" == *"idna-3.19.tar.gz"* ]]
	[[ "$output" != *"idna-3.7"* ]]
}

@test "generate_resources: the host's version of a package never replaces the analysis environment's" {
	install "$ENV_SITE" rootpkg 1.0.0 "click"
	install "$ENV_SITE" click 8.1.7
	install "$HOST_SITE" click 9.9.9
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *"click-8.1.7.tar.gz"* ]]
	[[ "$output" != *"9.9.9"* ]]
}

@test "generate_resources: a root package only the host has installed is not walked" {
	install "$HOST_SITE" rootpkg 1.0.0 "click==8.1.7"
	install "$HOST_SITE" click 8.1.7
	describe_env

	walk

	[ "$status" -ne 0 ]
	[[ "$output" == *"No dependencies to generate resources for"* ]]
}

@test "generate_resources: python_full_version markers use the analysis environment's patch release" {
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" 'mdurl==0.1.2; python_full_version >= "3.13.1"'
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "mdurl" do'* ]]

	# The same tree in an environment on the .0 release leaves it out.
	describe_env '.marker_env.python_full_version = "3.13.0"'

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "click" do'* ]]
	[[ "$output" != *'resource "mdurl" do'* ]]
}

@test "generate_resources: the sdist requires_python check uses the analysis environment's patch release" {
	# The newest idna release needs 3.14, so 3.13.5 gets 3.19. An
	# environment on 3.14.2 gets the newest one.
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "idna>=3.7"
	install "$ENV_SITE" click 8.1.7
	describe_env '.marker_env.python_full_version = "3.14.2" | .marker_env.python_version = "3.14"'

	PYTHONPATH="$HOST_SITE" run python3 "$SCRIPTS_DIR/generate_resources.py" rootpkg \
		--analysis-env "$ENV_JSON" --python-version 3.14

	[ "$status" -eq 0 ]
	[[ "$output" == *"idna-3.21.tar.gz"* ]]
}

@test "generate_resources: implementation markers follow the analysis environment, not the host" {
	# Both requirements are written so that exactly one matches whatever
	# Python runs this test: only the description can make both match.
	install "$ENV_SITE" rootpkg 1.0.0 \
		'click==8.1.7; implementation_version == "3.13.5"' \
		'mdurl==0.1.2; implementation_name == "fixturepy"'
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env '.marker_env.implementation_name = "fixturepy"'

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "click" do'* ]]
	[[ "$output" == *'resource "mdurl" do'* ]]
}

@test "generate_resources: platform markers are the formula's target, not the generator's machine" {
	# The description is of a Linux x86_64 runner; the formula is for macOS.
	install "$ENV_SITE" rootpkg 1.0.0 \
		'click==8.1.7; sys_platform == "darwin" and platform_system == "Darwin" and platform_machine == "arm64"' \
		'mdurl==0.1.2; sys_platform == "linux" or platform_release == "6.8.0-generic"'
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "click" do'* ]]
	[[ "$output" != *'resource "mdurl" do'* ]]

	walk --platform-machine x86_64

	[ "$status" -ne 0 ]
	[[ "$output" == *"No dependencies to generate resources for"* ]]
}

@test "generate_resources: an analysis environment on another Python than the formula's is refused" {
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7"
	install "$ENV_SITE" click 8.1.7
	describe_env '.marker_env.python_version = "3.12" | .marker_env.python_full_version = "3.12.9"'

	walk

	[ "$status" -ne 0 ]
	[[ "$output" == *"The analysis environment runs Python 3.12, but --python-version is 3.13"* ]]
}

@test "generate_resources: an incomplete or unreadable description is refused, never filled in from the host" {
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7"
	install "$ENV_SITE" click 8.1.7

	describe_env 'del(.marker_env.implementation_version)'
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"is missing marker values: implementation_version"* ]]

	describe_env '.marker_env.python_full_version = ""'
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"is missing marker values: python_full_version"* ]]

	describe_env '.site_paths = []'
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"lists no site_paths"* ]]

	describe_env '.site_paths = ["/nonexistent/site-packages"]'
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"site_paths that do not exist"* ]]

	printf 'not json' >"$ENV_JSON"
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"Cannot read the analysis environment description"* ]]

	rm "$ENV_JSON"
	walk
	[ "$status" -ne 0 ]
	[[ "$output" == *"Cannot read the analysis environment description"* ]]
}

@test "generate_resources: the description is required" {
	run python3 "$SCRIPTS_DIR/generate_resources.py" rootpkg --python-version 3.13

	[ "$status" -ne 0 ]
	[[ "$output" == *"--analysis-env"* ]]
}

@test "generate_resources: the first site directory wins when two hold the same package" {
	local second="$TEST_TEMP_DIR/env/platlib"
	mkdir -p "$second"
	install "$ENV_SITE" rootpkg 1.0.0 "click"
	install "$ENV_SITE" click 8.1.7
	install "$second" click 9.9.9
	describe_env ".site_paths += [\"$second\"]"

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *"click-8.1.7.tar.gz"* ]]
}

@test "probe_analysis_env: describes the interpreter it runs under with every marker value" {
	run python3 -I "$SCRIPTS_DIR/probe_analysis_env.py"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.marker_env | keys | length' <<<"$output")" -eq 11 ]
	[ "$(jq -r '.marker_env | has("extra")' <<<"$output")" = "false" ]
	[ "$(jq -r '.marker_env.python_full_version' <<<"$output")" = \
		"$(python3 -c 'import platform; print(platform.python_version())')" ]
	[ "$(jq -r '.marker_env.python_version' <<<"$output")" = \
		"$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')" ]
	[ "$(jq -r '.site_paths | length > 0' <<<"$output")" = "true" ]
	# Every directory it names exists, so the walk accepts the description.
	while IFS= read -r site_dir; do
		[ -d "$site_dir" ]
	done < <(jq -r '.site_paths[]' <<<"$output")
}

@test "probe_analysis_env: its marker values match packaging's for the same interpreter" {
	run python3 -c '
import json, subprocess, sys
from packaging.markers import default_environment

probed = json.loads(subprocess.check_output([sys.executable, "-I", sys.argv[1]]))["marker_env"]
expected = {k: v for k, v in default_environment().items() if k != "extra"}
assert probed == expected, (probed, expected)
' "$SCRIPTS_DIR/probe_analysis_env.py"

	[ "$status" -eq 0 ]
}

@test "pypi-resources: the walk is given the analysis environment's description and no PYTHONPATH" {
	local lib="$SCRIPTS_DIR/lib/pypi-resources.sh"

	grep -q -- '--analysis-env "\$analysis_env_json"' "$lib"
	grep -q '"\$analysis_venv/bin/python" -I "\$script_dir/probe_analysis_env.py"' "$lib"
	[ "$(grep -c 'PYTHONPATH=' "$lib")" -eq 0 ]
}
