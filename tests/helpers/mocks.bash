#!/usr/bin/env bash
# Mock gh CLI for merge bot tests.

# Recording gh mock for signed-commit and supersede tests.
# Logs every invocation (one line, space-joined) to $MOCK_GH_LOG and
# responds based on MOCK_* environment variables:
#   MOCK_MAIN_OID           SHA returned for git/ref/heads/main lookups
#   MOCK_REF_EXISTS         "true" fails ref creation (forces PATCH fallback)
#   MOCK_GRAPHQL_RESPONSE   JSON body returned for `gh api graphql`
#   MOCK_GH_GRAPHQL_PAYLOAD file capturing the GraphQL request payload
#   MOCK_REMOTE_FILE        file whose contents answer raw contents requests
#   MOCK_REMOTE_BLOB_SHA    sha answered for contents --jq .sha requests
#   MOCK_OPEN_PRS           JSON array answered for `gh pr list`
mock_gh_recording() {
	local mock_dir="$1"
	mkdir -p "$mock_dir"
	cat >"$mock_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

joined="$*"
if [[ -n "${MOCK_GH_LOG:-}" ]]; then
	echo "$joined" >>"$MOCK_GH_LOG"
fi

if [[ "$joined" == "api graphql --input -" ]]; then
	if [[ -n "${MOCK_GH_GRAPHQL_PAYLOAD:-}" ]]; then
		cat >"$MOCK_GH_GRAPHQL_PAYLOAD"
	else
		cat >/dev/null
	fi
	graphql_response="${MOCK_GRAPHQL_RESPONSE:-}"
	if [[ -z "$graphql_response" ]]; then
		graphql_response='{"data":{"createCommitOnBranch":{"commit":{"oid":"c0ffee","url":"https://example.invalid"}}}}'
	fi
	echo "$graphql_response"
	exit 0
fi

if [[ "$joined" == api\ repos/*/git/ref/heads/main* ]]; then
	echo "${MOCK_MAIN_OID:-1111111111111111111111111111111111111111}"
	exit 0
fi

if [[ "$joined" == api\ repos/*/git/refs\ -f\ ref=* ]]; then
	if [[ "${MOCK_REF_EXISTS:-}" == "true" ]]; then
		echo "Reference already exists" >&2
		exit 1
	fi
	echo "{}"
	exit 0
fi

if [[ "$joined" == api\ -X\ PATCH\ repos/*/git/refs/heads/* ]]; then
	echo "{}"
	exit 0
fi

if [[ "$joined" == *contents/* && "$joined" == *"--jq .sha"* ]]; then
	if [[ -n "${MOCK_CONTENTS_ERROR:-}" ]]; then
		echo "$MOCK_CONTENTS_ERROR" >&2
		exit 1
	fi
	if [[ -n "${MOCK_REMOTE_BLOB_SHA:-}" ]]; then
		echo "$MOCK_REMOTE_BLOB_SHA"
		exit 0
	fi
	echo "gh: Not Found (HTTP 404)" >&2
	exit 1
fi

if [[ "$joined" == *contents/* ]]; then
	if [[ -n "${MOCK_CONTENTS_ERROR:-}" ]]; then
		echo "$MOCK_CONTENTS_ERROR" >&2
		exit 1
	fi
	if [[ -n "${MOCK_REMOTE_FILE:-}" && -f "$MOCK_REMOTE_FILE" ]]; then
		cat "$MOCK_REMOTE_FILE"
		exit 0
	fi
	echo "gh: Not Found (HTTP 404)" >&2
	exit 1
fi

if [[ "$joined" == pr\ list* ]]; then
	json="${MOCK_OPEN_PRS:-[]}"
	jq_expr=""
	args=("$@")
	for ((i = 0; i < ${#args[@]}; i++)); do
		if [[ "${args[$i]}" == "--jq" ]]; then
			jq_expr="${args[$((i + 1))]}"
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

if [[ "$joined" == pr\ close* || "$joined" == pr\ comment* || "$joined" == pr\ create* ]]; then
	exit 0
fi

echo "unsupported gh invocation: $joined" >&2
exit 1
EOF
	chmod +x "$mock_dir/gh"
	export MOCK_GH_LOG="${MOCK_GH_LOG:-$mock_dir/gh.log}"
	: >"$MOCK_GH_LOG"
	export PATH="$mock_dir:$PATH"
}

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
