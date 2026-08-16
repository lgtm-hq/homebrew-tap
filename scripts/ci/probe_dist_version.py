#!/usr/bin/env python3
"""Print the installed version of a Python distribution.

Used by generate-pypi-formula.sh to decide whether a configured
wheel-only package is part of the release's dependency tree. Exit codes
distinguish "not installed" from genuine probe failures so the caller
can skip the former and hard-fail on the latter.

Usage:
    python3 probe_dist_version.py <distribution-name>

Exit codes:
    0: Distribution found; its version is printed to stdout.
    2: Usage error (missing argument).
    3: Distribution is not installed.
"""

import sys
from importlib.metadata import PackageNotFoundError, version

EXIT_USAGE: int = 2
EXIT_NOT_INSTALLED: int = 3


def main(argv: list[str]) -> int:
    """Resolve and print the installed version of a distribution.

    Args:
        argv: Command-line arguments (excluding the program name); the
            first entry is the distribution name to probe.

    Returns:
        Process exit code (see module docstring).
    """
    if len(argv) != 1:
        print("usage: probe_dist_version.py <distribution-name>", file=sys.stderr)
        return EXIT_USAGE
    try:
        print(version(argv[0]))
    except PackageNotFoundError:
        return EXIT_NOT_INSTALLED
    return 0


if __name__ == "__main__":
    sys.exit(main(argv=sys.argv[1:]))
