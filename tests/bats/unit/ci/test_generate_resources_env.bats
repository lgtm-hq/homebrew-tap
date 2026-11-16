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

# patchy 2.0 needs Python 3.13.3 or newer; 1.0 runs on any 3.x. Which one is
# pinned therefore depends on the patch release alone.
use_patchy_fixtures() {
	local fixtures="$TEST_TEMP_DIR/pypi"
	mkdir -p "$fixtures"
	cp "$PYPI_FIXTURE_DIR/click-8.1.7.json" "$fixtures/"
	python3 - "$fixtures" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])


def sdist(version, requires_python):
    return {
        "packagetype": "sdist",
        "filename": f"patchy-{version}.tar.gz",
        "url": f"https://files.pythonhosted.org/packages/fx/00/patchy-{version}.tar.gz",
        "digests": {"sha256": "e5" * 32},
        "requires_python": requires_python,
        "yanked": False,
    }


files = {"1.0": sdist("1.0", ">=3.6"), "2.0": sdist("2.0", ">=3.13.3")}
(root / "patchy.json").write_text(
    json.dumps(
        {
            "info": {"name": "patchy", "version": "2.0"},
            "releases": {version: [entry] for version, entry in files.items()},
        },
    ),
)
for version, entry in files.items():
    (root / f"patchy-{version}.json").write_text(
        json.dumps(
            {
                "info": {"name": "patchy", "version": version, "requires_dist": None},
                "urls": [entry],
            },
        ),
    )
PY
	export PYPI_FIXTURE_DIR="$fixtures"
}

@test "generate_resources: the sdist requires_python check uses the analysis environment's patch release" {
	use_patchy_fixtures
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "patchy"
	install "$ENV_SITE" click 8.1.7
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *"Resolved patchy==2.0 from PyPI"* ]]
	[[ "$output" == *"patchy-2.0.tar.gz"* ]]

	# The same tree in an environment on the .0 release gets the older one.
	describe_env '.marker_env.python_full_version = "3.13.0"'

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipping patchy 2.0: no sdist accepts Python 3.13.0 (requires_python)"* ]]
	[[ "$output" == *"patchy-1.0.tar.gz"* ]]
}

@test "generate_resources: the requires_python check counts a release candidate or a local build as its release, like pip" {
	# pip compares major.minor.micro only: 3.13.3rc1 and 3.13.3+ both
	# satisfy >=3.13.3. Compared as full versions, the candidate would not,
	# and the build suffix is not a version at all.
	use_patchy_fixtures
	install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "patchy"
	install "$ENV_SITE" click 8.1.7

	local full_version
	for full_version in "3.13.3rc1" "3.13.3+"; do
		describe_env ".marker_env.python_full_version = \"$full_version\""

		walk

		[ "$status" -eq 0 ]
		[[ "$output" == *"patchy-2.0.tar.gz"* ]]
	done
}

@test "generate_resources: implementation markers follow the analysis environment, not the host" {
	# No Python that runs this test is called "fixturepy", so the second
	# requirement matches only if the value comes from the description; the
	# first matches only on its implementation_version.
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
		'mdurl==0.1.2; sys_platform == "linux" or platform_system == "Linux" or os_name == "nt"'
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

@test "generate_resources: a requirement whose marker depends on the kernel is refused, not guessed" {
	# The kernel of the Macs a formula installs on is unknown. Each of these
	# would silently add or drop mdurl depending on what value is assumed.
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2

	# A description from a Mac is refused the same way as one from the Linux
	# runner: the generator's own kernel is not the target's either.
	local mac='.marker_env.sys_platform = "darwin" | .marker_env.platform_system = "Darwin" | .marker_env.platform_release = "23.5.0"'
	local marker description
	for marker in \
		'platform_release == "23.*"' \
		'platform_release == "23.5.*" or platform_release == "24.*"' \
		'platform_release > "999999"' \
		'"23.*" == platform_release' \
		'platform_version === "x"' \
		'(sys_platform == "darwin" and (platform_release >= "23" or os_name == "nt"))' \
		'platform_release >= "0"' \
		'platform_release != "0"' \
		'platform_version != "unused"' \
		'platform_release == "23.0.0"' \
		'"Darwin Kernel" in platform_version' \
		'platform_release ~= "23.1"' \
		'platform_release > "23" and platform_release < "24"' \
		'"23" < platform_release and "24" > platform_release' \
		'platform_release in "abc" and platform_release != "" and platform_release != "abc"' \
		'platform_release == platform_version' \
		'sys_platform == "darwin" and platform_release >= "23"'; do
		rm -rf "$ENV_SITE"/rootpkg-*
		install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "mdurl==0.1.2; $marker"

		for description in '.' "$mac"; do
			describe_env "$description"

			walk

			[ "$status" -ne 0 ]
			[[ "$output" == *"Cannot decide 'mdurl==0.1.2; $marker' (required by rootpkg)"* ]]
			[[ "$output" == *"depends on platform_release or platform_version"* ]]
			[[ "$output" != *'resource "'* ]]
			[[ "$output" != *"Traceback"* ]]
		done
	done
}

@test "generate_resources: a kernel marker that another clause already decides is not refused" {
	# The kernel values cannot change any of these answers, so there is
	# nothing to guess: two never apply to the macOS target or to a root
	# without the extra, one always applies. The kernel comparison itself is
	# never evaluated: `~=` against an empty value raises in some supported
	# versions of packaging.
	install "$ENV_SITE" rootpkg 1.0.0 \
		'click==8.1.7; sys_platform == "darwin" or platform_release ~= "23.1"' \
		'mdurl==0.1.2; sys_platform == "linux" and platform_version ~= "1.0"' \
		'idna>=3.7; extra == "dev" and platform_version != "unused"'
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "click" do'* ]]
	[[ "$output" != *'resource "mdurl" do'* ]]
	[[ "$output" != *'idna'* ]]

	# Once the extra is requested, the kernel clause decides: refused.
	walk --extras dev

	[ "$status" -ne 0 ]
	[[ "$output" == *"Cannot decide 'idna>=3.7; extra == \"dev\" and platform_version != \"unused\"'"* ]]
}

@test "generate_resources: quotes and marker syntax inside a string do not hide a kernel comparison" {
	# Each of these is decided by the kernel and was once decided silently:
	# the marker was rewritten as text and a quote inside a string shifted
	# where the next string began, or (the last three) both operands are
	# quoted strings and packaging looks the right one up as a name.
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env

	local marker
	while IFS= read -r marker; do
		rm -rf "$ENV_SITE"/rootpkg-*
		install "$ENV_SITE" rootpkg 1.0.0 "click==8.1.7" "mdurl==0.1.2; $marker"

		walk

		[ "$status" -ne 0 ]
		[[ "$output" == *"Cannot decide 'mdurl==0.1.2; $marker' (required by rootpkg)"* ]]
		[[ "$output" != *'resource "'* ]]
		[[ "$output" != *"Traceback"* ]]
	done <<'MARKERS'
(os_name == 'a "' or platform_version not in " in x") and (sys_platform == "darwin" or platform_release == "1")
(os_name == 'a "' or platform_version in " in x") and (sys_platform == "darwin" or platform_release == "1")
platform_release >= "5" and os_name != 'a" and os_name != "posix'
platform_release >= "5" or os_name == 'a" or os_name == "posix'
platform_version != 'a "'
os_name not in 'platform_release == "x"' and platform_release == "23"
"25.1.0" == "platform_release"
"25.1.0" != "platform_release"
"Darwin" in "platform_version"
MARKERS
}

@test "generate_resources: a kernel variable's name inside a string is a value, not a kernel marker" {
	# None of these reads the kernel: with a variable on the left, the right
	# operand is only text to compare with.
	install "$ENV_SITE" rootpkg 1.0.0 \
		'click==8.1.7; platform_machine != "platform_release"' \
		"mdurl==0.1.2; os_name in 'platform_version == \"posix\"'" \
		'idna>=3.7; extra == "platform_release"'
	install "$ENV_SITE" click 8.1.7
	install "$ENV_SITE" mdurl 0.1.2
	describe_env

	walk

	[ "$status" -eq 0 ]
	[[ "$output" == *'resource "click" do'* ]]
	[[ "$output" == *'resource "mdurl" do'* ]]
	[[ "$output" != *'idna'* ]]
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

	# An unreadable or foreign release would make python_full_version
	# markers quietly evaluate false.
	local full_version
	for full_version in "garbage" "3.13.5.final.0" "3.13" "3.12.9" "3.130.1"; do
		describe_env ".marker_env.python_full_version = \"$full_version\""
		walk
		[ "$status" -ne 0 ]
		[[ "$output" == *"gives python_full_version '$full_version', which is not a Python 3.13 release"* ]]
	done

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
