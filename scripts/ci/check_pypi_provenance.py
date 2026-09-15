#!/usr/bin/env python3
"""Cross-check a PyPI file against its PEP 740 provenance.

PyPI serves the publish attestations it received for a file at
``https://pypi.org/integrity/<project>/<version>/<file>/provenance``. The
check binds the digest the tap is about to pin to what PyPI stored: the
provenance must exist, its publisher must be the expected GitHub repository
(and workflow, when given), and an attestation subject must name the file
with the same sha256.

This is a metadata cross-check, not a signature verification; the Sigstore
signature on the same artifact is checked separately with
``gh attestation verify`` (see scripts/ci/lib/provenance.sh).

Exit codes:
    0: provenance matches.
    1: provenance missing or inconsistent (reasons on stderr).
"""

from __future__ import annotations

import argparse
import sys

from pypi_utils import fetch_pypi_provenance, provenance_errors


def main() -> int:
    """Run the PEP 740 cross-check from the command line.

    Returns:
        Process exit code.
    """
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("package", help="PyPI project name")
    parser.add_argument("version", help="Release version")
    parser.add_argument("filename", help="Distribution filename (e.g. pkg-1.0.tar.gz)")
    parser.add_argument("--sha256", required=True, help="Expected sha256 of the file")
    parser.add_argument(
        "--repo",
        required=True,
        help="Expected Trusted Publisher repository (owner/repo)",
    )
    parser.add_argument(
        "--workflow",
        default="",
        help="Expected Trusted Publisher workflow filename (optional)",
    )
    args = parser.parse_args()

    data = fetch_pypi_provenance(args.package, args.version, args.filename)
    if data is None:
        print(
            f"Error: PyPI has no PEP 740 provenance for {args.filename} "
            f"({args.package} {args.version})",
            file=sys.stderr,
        )
        return 1

    errors = provenance_errors(
        data=data,
        filename=args.filename,
        sha256=args.sha256,
        repo=args.repo,
        workflow=args.workflow or None,
    )
    if errors:
        print(
            f"Error: PEP 740 provenance for {args.filename} does not match:",
            file=sys.stderr,
        )
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(
        f"PEP 740 provenance for {args.filename} matches: publisher {args.repo}"
        f"{' / ' + args.workflow if args.workflow else ''}, sha256 {args.sha256}",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
