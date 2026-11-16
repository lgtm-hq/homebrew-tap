#!/usr/bin/env python3
"""Print a formula's configured extras as a comma-separated list.

Usage:
    python3 read_extras.py '<formula-config-json>'

The formula config's ``extras`` key must be absent, null or a list of extra
names. Each name is interpolated into Ruby source and pip arguments, so it
must fit the PEP 685 charset. Prints nothing when no extras are configured.

Exit codes:
    0: Valid; the list (possibly empty) is printed.
    1: ``extras`` is not a list, or an entry is not a valid extra name.
    2: Usage error.
"""

from __future__ import annotations

import json
import re
import sys

EXTRA_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
EXIT_INVALID: int = 1
EXIT_USAGE: int = 2


def main(argv: list[str]) -> int:
    """Validate and print the extras of one formula config.

    Args:
        argv: Command-line arguments (excluding the program name); the
            first entry is the formula config as JSON.

    Returns:
        Process exit code.
    """
    if len(argv) != 1:
        print("Usage: read_extras.py '<formula-config-json>'", file=sys.stderr)
        return EXIT_USAGE
    extras = json.loads(argv[0]).get("extras")
    if extras is None:
        return 0
    if not isinstance(extras, list):
        print(f"extras must be a list, got {extras!r}", file=sys.stderr)
        return EXIT_INVALID
    for extra in extras:
        if not isinstance(extra, str) or not EXTRA_NAME.fullmatch(extra):
            print(f"extras entry {extra!r} is not a valid extra name", file=sys.stderr)
            return EXIT_INVALID
    print(",".join(extras))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
