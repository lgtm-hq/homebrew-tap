#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Purpose: Tests for render_formula.py template rendering.

load "../../../helpers/common"

setup() {
	setup_temp_dir
	REPO_ROOT="$(repo_root)"
	bootstrap_test_env "$REPO_ROOT"
	SCRIPTS_DIR="$REPO_ROOT/scripts/ci"
}

teardown() {
	teardown_temp_dir
}

@test "render-formula: renders simple template replacements" {
	template_file="$TEST_TEMP_DIR/template.rb"
	output_file="$TEST_TEMP_DIR/output.rb"
	cat >"$template_file" <<'EOF'
class {{CLASS_NAME}} < Formula
  desc "{{DESCRIPTION}}"
end
EOF

	run python3 "$SCRIPTS_DIR/render_formula.py" \
		--template "$template_file" \
		--replace "CLASS_NAME=Example" \
		--replace "DESCRIPTION=An example formula" \
		--output "$output_file"

	[ "$status" -eq 0 ]
	grep -q 'class Example < Formula' "$output_file"
	grep -q 'desc "An example formula"' "$output_file"
}

@test "render-formula: fails on unreplaced placeholders" {
	template_file="$TEST_TEMP_DIR/template.rb"
	cat >"$template_file" <<'EOF'
class {{CLASS_NAME}} < Formula
  desc "{{DESCRIPTION}}"
end
EOF

	run python3 "$SCRIPTS_DIR/render_formula.py" \
		--template "$template_file" \
		--replace "CLASS_NAME=Example"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Unreplaced template placeholders"* ]]
}

@test "render-formula: rejects malformed replacement arguments" {
	template_file="$TEST_TEMP_DIR/template.rb"
	cat >"$template_file" <<'EOF'
class {{CLASS_NAME}} < Formula
end
EOF

	run python3 "$SCRIPTS_DIR/render_formula.py" \
		--template "$template_file" \
		--replace "CLASS_NAME" \
		--output "$TEST_TEMP_DIR/output.rb"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid --replace argument"* ]]
}
