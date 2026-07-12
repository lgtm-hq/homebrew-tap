#!/usr/bin/env python3
"""Detect runtime dependency drift between two PyPI package versions.

Compares the ``Requires-Dist`` metadata (``info.requires_dist`` in the PyPI
JSON API) of the previous and new versions of a package. Drift means the
formula's resource stanzas derived from the previous version are stale.

Exit codes:
  0  No drift, or drift detected in ``warn`` mode (resources are
     regenerated automatically for this formula).
  1  Drift detected in ``fail`` mode; the operator must regenerate the
     resource stanzas before the bump can proceed.
"""

import argparse
import sys

from pypi_utils import fetch_pypi_json


def requires_dist(package: str, version: str) -> set[str]:
    """Fetch the normalized Requires-Dist set for a package version.

    Args:
        package: Package name on PyPI.
        version: Exact version to inspect.

    Returns:
        Set of requirement strings with surrounding whitespace stripped.
    """
    data = fetch_pypi_json(package, version)
    entries = data.get("info", {}).get("requires_dist") or []
    return {entry.strip() for entry in entries if entry and entry.strip()}


def main() -> int:
    """Compare Requires-Dist between two versions and report drift.

    Returns:
        Process exit code (0 on success/warn, 1 on drift in fail mode).
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", help="PyPI package name")
    parser.add_argument(
        "--previous-version",
        required=True,
        help="Version currently published in the formula",
    )
    parser.add_argument(
        "--new-version",
        required=True,
        help="Version being bumped to",
    )
    parser.add_argument(
        "--mode",
        choices=("fail", "warn"),
        default="fail",
        help=(
            "fail: exit 1 on drift (static resource stanzas must be "
            "regenerated); warn: report drift but exit 0 (resources are "
            "regenerated automatically)"
        ),
    )
    args = parser.parse_args()

    previous = requires_dist(args.package, args.previous_version)
    new = requires_dist(args.package, args.new_version)

    if previous == new:
        print(
            f"No Requires-Dist drift for {args.package} "
            f"{args.previous_version} -> {args.new_version}"
        )
        return 0

    print(
        f"Requires-Dist drift detected for {args.package} "
        f"{args.previous_version} -> {args.new_version}:",
        file=sys.stderr,
    )
    for entry in sorted(new - previous):
        print(f"  + {entry}", file=sys.stderr)
    for entry in sorted(previous - new):
        print(f"  - {entry}", file=sys.stderr)

    if args.mode == "warn":
        print(
            "Resource stanzas are regenerated automatically for this "
            "formula; continuing.",
            file=sys.stderr,
        )
        return 0

    print(
        "ERROR: runtime dependencies changed between versions but this "
        "formula does not regenerate resource stanzas automatically. "
        "Regenerate the resource stanzas (scripts/ci/generate-pypi-"
        "formula.sh with generate-resources enabled, or a manual "
        "'brew update-python-resources' pass) and re-run the update.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
