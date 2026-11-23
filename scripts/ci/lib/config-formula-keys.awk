# config-formula-keys.awk
# List the formula keys under the top-level `formulas:` mapping of a product
# config (formulas/*.yml), one per line, for detect-formula-changes.sh.
#
# The `changes` job has no Python, so this cannot use read_formula_config.py.
# It is not a YAML parser: it accepts only the plain layout the configs use
# and exits 2, printing nothing, for anything else, so the caller validates
# every formula instead of trusting a guess (lgtm-hq/homebrew-tap#661):
#
#   - one document: an optional leading `---`, no other `---`, no `...`, no
#     `%` directives, no carriage returns;
#   - block mappings and sequences indented with spaces only (no tab outside
#     a block scalar's text); every line sits at the indentation of its
#     parent's first child, deeper only under a `key:` or `-` with no value;
#   - mapping keys are plain and unquoted; `?` and `:` entries, merge keys and
#     an anchor or tag on `formulas:` itself are refused;
#   - `formulas:` appears once, at the top level, and every key directly
#     under it is a lowercase name starting with a letter that YAML does not
#     read as a boolean or null;
#   - values are plain one-line scalars, block scalars (`|`, `>`), quoted
#     scalars closed on the same line, or flow collections without quotes
#     closed on the same line, so no value runs onto a following line.
#
# tests/helpers/awk_reader_property.py checks it against
# read_formula_config.py --list-formulas over generated layouts.
#
# Usage: awk -f config-formula-keys.awk formulas/<config>.yml
# POSIX awk only: it runs under mawk or gawk on the Ubuntu runner.

function reject() {
	rejected = 1
	exit 2
}

# Check one value (the text after `key:` or `- `). Returns 1 when the value
# is empty, so the entry's content follows on deeper lines. Sets block_start
# when the value opens a block scalar.
function check_value(value,    first, level, i, probe) {
	sub(/^ +/, "", value)
	# Anchors and tags in front of the value.
	while (value ~ /^[&!][^ ]*( |$)/) {
		sub(/^[&!][^ ]*/, "", value)
		sub(/^ +/, "", value)
	}
	if (value == "" || value ~ /^#/) {
		return 1
	}
	first = substr(value, 1, 1)
	if (first == "|" || first == ">") {
		if (value !~ /^[|>][-+0-9]*( +#.*)?$/) {
			reject()
		}
		block_start = 1
		return 0
	}
	if (first == "'") {
		if (value !~ /^'([^']|'')*'( +#.*)? *$/) {
			reject()
		}
		return 0
	}
	if (first == "\"") {
		if (value !~ /^"([^"\\]|\\.)*"( +#.*)? *$/) {
			reject()
		}
		return 0
	}
	sub(/ +#.*$/, "", value)
	sub(/ +$/, "", value)
	if (first == "[" || first == "{") {
		if (value ~ /["'#]/) {
			reject()
		}
		level = 0
		for (i = 1; i <= length(value); i++) {
			probe = substr(value, i, 1)
			if (probe == "[" || probe == "{") {
				level++
			} else if (probe == "]" || probe == "}") {
				level--
			}
			if (level == 0 && i < length(value)) {
				reject()
			}
		}
		if (level != 0) {
			reject()
		}
		return 0
	}
	# A plain scalar: no indicator that starts something else, and no
	# `: ` or trailing `:` that would make it a key.
	if (index("]}`@%,", first) > 0 || value ~ /^[-?:]( |$)/) {
		reject()
	}
	if (first == "*" && value !~ /^\*[^ ]+$/) {
		reject()
	}
	if (value ~ /: / || value ~ /:$/) {
		reject()
	}
	return 0
}

function push(indent, kind, compact) {
	depth++
	st_indent[depth] = indent
	st_kind[depth] = kind
	st_compact[depth] = compact
}

# Handle `key: value` whose key starts at column col, in the mapping at the
# top of the stack.
function handle_key(entry, col,    name, value) {
	if (depth == 1) {
		if (!match(entry, /^[A-Za-z_][A-Za-z0-9_-]*:( +|$)/)) {
			reject()
		}
	} else if (!match(entry, /^[A-Za-z0-9_][A-Za-z0-9_.@+\/-]*:( +|$)/)) {
		reject()
	}
	value = substr(entry, RLENGTH + 1)
	name = entry
	sub(/:.*$/, "", name)
	if (depth == 1 && name == "formulas") {
		if (seen_formulas || value !~ /^( *#.*)? *$/) {
			reject()
		}
		seen_formulas = 1
		opening_formulas = 1
		pending = 1
		return
	}
	if (depth == formulas_depth) {
		if (name !~ /^[a-z][a-z0-9+_.@-]*$/ ||
			name ~ /^(yes|no|on|off|true|false|null)$/) {
			reject()
		}
		keys[++count] = name
	}
	block_start = 0
	if (check_value(value)) {
		pending = 1
	}
	if (block_start) {
		in_block = 1
		block_parent = col
		block_indent = 0
	}
}

BEGIN {
	depth = 0
	push(0, "map", 0)
	formulas_depth = -1
}

{
	line = $0
	if (line ~ /\r/) {
		reject()
	}
	match(line, /^ */)
	indent = RLENGTH

	# Text of a block scalar: every blank line and every line indented more
	# than the entry that opened it, at least as deep as its first line.
	if (in_block) {
		if (line ~ /^ *$/) {
			next
		}
		if (indent > block_parent) {
			if (block_indent == 0) {
				block_indent = indent
			}
			if (indent < block_indent || line ~ /^ *\t/) {
				reject()
			}
			next
		}
		in_block = 0
	}

	if (line ~ /\t/) {
		reject()
	}
	if (line ~ /^ *$/ || line ~ /^ *#/) {
		next
	}
	content = substr(line, indent + 1)
	if (indent == 0 && content ~ /^---( +#.*)? *$/ && !seen_content) {
		seen_content = 1
		next
	}
	seen_content = 1
	is_seq = (content ~ /^-( |$)/)

	# After a `key:` or `-` with no value, a deeper line starts its content;
	# a sequence may also start at the key's own indentation.
	if (pending) {
		pending = 0
		if (indent > st_indent[depth]) {
			push(indent, is_seq ? "seq" : "map", 0)
		} else if (indent == st_indent[depth] && is_seq && st_kind[depth] == "map") {
			push(indent, "seq", 1)
		}
		if (opening_formulas) {
			opening_formulas = 0
			if (depth == 2 && st_kind[2] == "map") {
				formulas_depth = 2
			}
		}
	}
	while (depth > 1 && (st_indent[depth] > indent ||
		(st_indent[depth] == indent && st_compact[depth] && !is_seq))) {
		depth--
	}
	if (depth < formulas_depth) {
		formulas_depth = -1
	}
	if (st_indent[depth] != indent || (st_kind[depth] == "seq") != is_seq) {
		reject()
	}

	if (!is_seq) {
		handle_key(content, indent)
		next
	}
	entry = substr(content, 2)
	match(entry, /^ */)
	col = indent + 1 + RLENGTH
	entry = substr(entry, RLENGTH + 1)
	if (entry ~ /^[-?:]( |$)/) {
		reject()
	}
	if (match(entry, /^[A-Za-z0-9_][A-Za-z0-9_.@+\/-]*:( +|$)/)) {
		push(col, "map", 0)
		handle_key(entry, col)
		next
	}
	block_start = 0
	if (check_value(entry)) {
		pending = 1
	}
	if (block_start) {
		in_block = 1
		block_parent = indent
		block_indent = 0
	}
}

END {
	# No top-level formulas: mapping, or one with no keys (empty, null or a
	# sequence), is not the plain layout: refuse it here rather than rely on
	# the caller reading empty output as "validate every formula".
	if (rejected || !seen_formulas || count == 0) {
		exit 2
	}
	for (i = 1; i <= count; i++) {
		print keys[i]
	}
}
