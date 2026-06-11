#!/usr/bin/env bash
# Common helpers for homebrew-tap BATS tests.

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
	cd "$(dirname "${BATS_TEST_FILENAME}")/../../../../" && pwd
}

assert_files_equal() {
	local expected="$1"
	local actual="$2"
	diff -u "$expected" "$actual"
}
