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
	json="[]"
	if [[ -n "${MOCK_PR_NUMBER:-}" ]]; then
		json="[{\"number\": ${MOCK_PR_NUMBER}}]"
	fi

	jq_expr=""
	for ((i = 0; i < ${#cmd[@]}; i++)); do
		if [[ "${cmd[$i]}" == "--jq" ]]; then
			jq_expr="${cmd[$((i + 1))]}"
			break
		fi
	done

	if [[ -n "$jq_expr" ]]; then
		echo "$json" | jq -r "$jq_expr"
	else
		echo "$json"
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
