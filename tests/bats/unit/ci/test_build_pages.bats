#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for build_pages.py landing-page generator.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	ensure_test_python_deps "$REPO_ROOT"
	OUT="$TEST_TEMP_DIR/index.html"
}

teardown() {
	teardown_temp_dir
}

build() {
	python3 "$REPO_ROOT/scripts/ci/build_pages.py" --output "$OUT"
}

@test "build-pages: generates a complete self-contained document" {
	run build
	[ "$status" -eq 0 ]
	grep -q '<!doctype html>' "$OUT"
	grep -q 'id="formulae"' "$OUT"
	grep -q 'id="flow"' "$OUT"
	grep -q '<footer' "$OUT"
	# render_page must leave no unreplaced placeholders
	! grep -qE '\{\{[^}]+\}\}' "$OUT"
}

@test "build-pages: one product card per product config" {
	build
	cards=$(grep -o '<article class="card">' "$OUT" | wc -l | tr -d ' ')
	configs=$(find "$REPO_ROOT/formulas" -maxdepth 1 -name '*.yml' | wc -l | tr -d ' ')
	[ "$cards" -eq "$configs" ]
}

@test "build-pages: lintro variants are grouped; winnow is its own product" {
	build
	grep -q 'brew install lintro' "$OUT"
	grep -q 'brew install lintro-full' "$OUT"
	grep -q 'brew install winnow' "$OUT"
	grep -q 'Standalone binary' "$OUT"
	grep -q 'Full toolkit' "$OUT"
}

@test "build-pages: tool count is derived from homebrew-deps, not hardcoded" {
	build
	# The full toolkit tag reflects the real dependency count in the config.
	deps=$(python3 -c "
import yaml, sys
cfg = yaml.safe_load(open('${REPO_ROOT}/formulas/lintro.yml'))
print(len(cfg['formulas']['lintro-full']['homebrew-deps']))
")
	[ -n "$deps" ]
	grep -q "${deps} tools" "$OUT"
}

@test "build-pages: versions are read live from Formula/*.rb, not pinned" {
	build
	# Binary formula: explicit version field.
	lver=$(sed -nE 's/^[[:space:]]*version[[:space:]]+"([^"]+)".*/\1/p' \
		"$REPO_ROOT/Formula/lintro.rb" | head -1)
	[ -n "$lver" ]
	grep -q "$lver" "$OUT"
	# PyPI formula: version embedded in the sdist url filename.
	wver=$(grep -oE 'winnow_media-[0-9][^"/]*\.tar\.gz' \
		"$REPO_ROOT/Formula/winnow.rb" | head -1 |
		sed -E 's/winnow_media-(.*)\.tar\.gz/\1/')
	[ -n "$wver" ]
	grep -q "$wver" "$OUT"
}

@test "build-pages: page is self-contained (no external hosts beyond github.com)" {
	build
	# Every absolute URL must point at github.com — no CDN/font/script origins.
	run bash -c \
		"grep -oE 'https?://[^\"'\'' )]+' '$OUT' | grep -vE '^https?://github\.com/' || true"
	[ -z "$output" ]
}
