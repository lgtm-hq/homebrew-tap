#!/usr/bin/env bash
# Common helpers for homebrew-tap BATS tests.

ensure_uv() {
	if command -v uv >/dev/null 2>&1; then
		return 0
	fi

	# CI shell-tests do not run setup-python. Install a pinned uv release binary
	# (not curl|sh) so the download is version-locked and fails closed on HTTP errors.
	local uv_version="0.9.26"
	local arch
	case "$(uname -m)" in
	arm64 | aarch64) arch="aarch64" ;;
	x86_64 | amd64) arch="x86_64" ;;
	*)
		echo "ensure_uv: unsupported architecture: $(uname -m)" >&2
		return 1
		;;
	esac

	local os
	case "$(uname -s)" in
	Darwin) os="apple-darwin" ;;
	Linux) os="unknown-linux-gnu" ;;
	*)
		echo "ensure_uv: unsupported OS: $(uname -s)" >&2
		return 1
		;;
	esac

	local bindir="${HOME}/.local/bin"
	local tarball="uv-${arch}-${os}.tar.gz"
	local url="https://github.com/astral-sh/uv/releases/download/${uv_version}/${tarball}"
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$bindir"
	curl -fsSL "$url" -o "${tmp}/${tarball}"
	tar -xzf "${tmp}/${tarball}" -C "$tmp"
	install -m 0755 "${tmp}/uv-${arch}-${os}/uv" "${bindir}/uv"
	rm -rf "$tmp"
	export PATH="${bindir}:${PATH}"
	command -v uv >/dev/null 2>&1
}

ensure_test_python_deps() {
	local repo_root="$1"

	ensure_uv || return 1
	(cd "$repo_root" && uv sync --quiet) || return 1
	# shellcheck disable=SC1091
	source "$repo_root/.venv/bin/activate"
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
