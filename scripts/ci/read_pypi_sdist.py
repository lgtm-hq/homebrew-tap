#!/usr/bin/env python3
"""Read PyPI sdist URL and SHA256 (supports PYPI_FIXTURE_DIR for tests)."""

import sys

from pypi_utils import fetch_pypi_json, get_sdist_info


def main() -> None:
    """Print tarball URL and SHA256 on separate lines."""
    if len(sys.argv) != 3:
        print("Usage: read_pypi_sdist.py <package> <version>", file=sys.stderr)
        sys.exit(1)

    package = sys.argv[1]
    version = sys.argv[2]
    data = fetch_pypi_json(package, version=version)
    info = get_sdist_info(data)
    print(info.tarball_url)
    print(info.tarball_sha256)


if __name__ == "__main__":
    main()
