#!/usr/bin/env bash
# Common helpers for homebrew-tap BATS tests.

ensure_test_python_deps() {
	local repo_root="$1"
	local venv="$repo_root/.test-venv"
	local sentinel="$venv/.deps-installed"

	if [[ ! -d "$venv" ]]; then
		python3 -m venv "$venv"
	fi
	# shellcheck disable=SC1091
	source "$venv/bin/activate"

	if [[ -f "$sentinel" ]]; then
		return 0
	fi

	python -m pip install --quiet --upgrade pip
	python -m pip install --quiet -r "$repo_root/requirements-test.txt"
	touch "$sentinel"
}

bootstrap_test_env() {
	local repo_root="$1"

	bash "$repo_root/scripts/ci/ensure-lgtm-ci-tooling.sh"
	export LGTM_CI_TOOLING_DIR="$repo_root/.lgtm-ci-tooling"
	ensure_test_python_deps "$repo_root"
}

setup_temp_dir() {
	TEST_TEMP_DIR="$(mktemp -d "${BATS_TEST_TMPDIR}/homebrew-tap-test.XXXXXX")"
	export TEST_TEMP_DIR
}

teardown_temp_dir() {
	if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
		rm -rf "$TEST_TEMP_DIR"
	fi
}

repo_root() {
	local dir
	dir="$(dirname "${BATS_TEST_FILENAME}")"
	while [[ "$dir" != "/" ]]; do
		if [[ -e "$dir/.git" ]]; then
			cd "$dir" && pwd
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	return 1
}

assert_files_equal() {
	local expected="$1"
	local actual="$2"
	diff -u "$expected" "$actual"
}
