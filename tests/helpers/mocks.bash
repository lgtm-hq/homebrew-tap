#!/usr/bin/env bash
# Mock gh CLI for merge bot tests.

mock_gh() {
	local mock_dir="$1"
	mkdir -p "$mock_dir"
	cat >"$mock_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd=("$@")

if [[ "${cmd[0]}" == "pr" && "${cmd[1]}" == "list" ]]; then
	if [[ -n "${MOCK_PR_NUMBER:-}" ]]; then
		echo "${MOCK_PR_NUMBER}"
	fi
	exit 0
fi

if [[ "${cmd[0]}" == "pr" && "${cmd[1]}" == "view" ]]; then
	joined="$*"
	if [[ "$joined" == *"author"* ]]; then
		echo "${MOCK_AUTHOR:-github-actions[bot]}"
		exit 0
	fi
	if [[ "$joined" == *"title"* ]]; then
		echo "${MOCK_TITLE:-chore(homebrew): update winnow to 0.0.1}"
		exit 0
	fi
fi

if [[ "${cmd[0]}" == "pr" && "${cmd[1]}" == "merge" ]]; then
	echo "merged"
	exit 0
fi

echo "unsupported gh invocation: $*" >&2
exit 1
EOF
	chmod +x "$mock_dir/gh"
	export PATH="$mock_dir:$PATH"
}
