#!/usr/bin/env python3
"""Describe the interpreter this runs under, for the dependency walk.

generate_resources.py runs on the generator host's Python, which is not the
Python the formula installs with. This script is run by the analysis
environment's own interpreter and prints the two things the walk must take
from that environment instead of from its host:

- ``site_paths``: the directories its installed distributions live in;
- ``marker_env``: its PEP 508 marker values, including the real
  ``python_full_version`` (the patch release pip resolved under).

It imports the standard library only, so it needs nothing installed in the
environment it describes.

Usage:
    <analysis-venv>/bin/python -I probe_analysis_env.py > analysis-env.json
"""

from __future__ import annotations

import json
import os
import platform
import site
import sys
import sysconfig


def _implementation_version() -> str:
    """Format ``sys.implementation.version`` the way PEP 508 defines it.

    Returns:
        The implementation version, e.g. ``3.13.5`` or ``3.15.0rc1``.
    """
    info = sys.implementation.version
    version = f"{info.major}.{info.minor}.{info.micro}"
    if info.releaselevel != "final":
        version += f"{info.releaselevel[0]}{info.serial}"
    return version


def marker_environment() -> dict[str, str]:
    """Build the PEP 508 marker environment of the running interpreter.

    Returns:
        Every marker variable PEP 508 defines, except ``extra``.
    """
    return {
        "implementation_name": sys.implementation.name,
        "implementation_version": _implementation_version(),
        "os_name": os.name,
        "platform_machine": platform.machine(),
        "platform_python_implementation": platform.python_implementation(),
        "platform_release": platform.release(),
        "platform_system": platform.system(),
        "platform_version": platform.version(),
        "python_full_version": platform.python_version(),
        "python_version": ".".join(platform.python_version_tuple()[:2]),
        "sys_platform": sys.platform,
    }


def site_paths() -> list[str]:
    """List the directories that hold this interpreter's distributions.

    Returns:
        Existing site directories in import order, without duplicates.
        Pure and platform library directories are both included, so a split
        layout cannot hide a distribution. An interpreter may name a
        directory it never created (a platform library directory with
        nothing in it); nothing can be installed there, so it is left out.
    """
    candidates = [
        *site.getsitepackages(),
        sysconfig.get_path("purelib"),
        sysconfig.get_path("platlib"),
    ]
    paths: list[str] = []
    for candidate in candidates:
        if candidate and candidate not in paths and os.path.isdir(candidate):
            paths.append(candidate)
    return paths


def main() -> None:
    """Print the description as one JSON object."""
    json.dump(
        {"site_paths": site_paths(), "marker_env": marker_environment()},
        sys.stdout,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
