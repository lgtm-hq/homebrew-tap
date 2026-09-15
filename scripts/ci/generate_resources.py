#!/usr/bin/env python3
"""Generate Homebrew resource stanzas for Python package dependencies.

This is a modern replacement for homebrew-pypi-poet that:
- Uses importlib.metadata instead of deprecated pkg_resources
- Uses pypi.org API directly (via pypi_utils)
- Generates resource stanzas compatible with Homebrew formulae

Usage:
    # Generate resources for a package installed in current environment
    python3 generate_resources.py lintro

    # Exclude specific packages (e.g., already available as Homebrew formulae)
    python3 generate_resources.py lintro --exclude bandit black mypy ruff yamllint

    # Follow the root package's extras and resolve for an Intel Mac
    python3 generate_resources.py lintro --extras mcp --platform-machine x86_64

Requirements that the analysis environment did not install (a dependency
gated on a marker that is false where the analysis ran, e.g. macOS x86_64
only) are resolved from PyPI: the newest final release satisfying the
specifier is pinned and its own requirements are walked the same way.
"""

from __future__ import annotations

import argparse
import sys
from importlib.metadata import distributions
from typing import Any

from packaging.requirements import InvalidRequirement, Requirement
from packaging.specifiers import InvalidSpecifier, SpecifierSet
from packaging.version import InvalidVersion, Version

from pypi_utils import fetch_pypi_json, get_sdist_info, normalize_name

# Homebrew macOS Python formula install environment for marker evaluation.
# platform_machine is set per run (--platform-machine): arm64 for Apple
# silicon formulas, x86_64 for the Intel branch of a binary formula.
TARGET_ENV: dict[str, str] = {
    "python_version": "3.13",
    "python_full_version": "3.13.0",
    "sys_platform": "darwin",
    "os_name": "posix",
    "platform_system": "Darwin",
    "platform_machine": "arm64",
}

# Requirements not installed in the analysis environment, resolved from
# PyPI metadata: normalized name -> (version, requires_dist).
_RESOLVED_FROM_PYPI: dict[str, tuple[str, list[str] | None]] = {}

# Template for a single resource stanza
RESOURCE_TEMPLATE = """  resource "{name}" do
    url "{url}"
    sha256 "{sha256}"
  end
"""


def build_distribution_map() -> dict[str, tuple[str, list[str] | None]]:
    """Build a cached map of all installed distributions.

    Returns:
        Dictionary mapping normalized package names to (version, requires) tuples.
    """
    dist_map: dict[str, tuple[str, list[str] | None]] = {}
    for dist in distributions():
        name = dist.metadata["Name"]
        version = dist.metadata["Version"]
        if name and version:
            normalized = normalize_name(name)
            requires = dist.metadata.get_all("Requires-Dist")
            dist_map[normalized] = (version, requires)
    return dist_map


def get_installed_packages() -> dict[str, str]:
    """Get all installed packages and their versions.

    Returns:
        Dictionary mapping normalized package names to versions.
    """
    dist_map = build_distribution_map()
    return {name: version for name, (version, _) in dist_map.items()}


def _marker_matches(req: Requirement, extras: frozenset[str]) -> bool:
    """Evaluate a requirement marker for the target environment.

    Extras-gated requirements (e.g. ``ruamel.yaml ; extra == "yaml"``)
    only match when the dependent was requested with that extra, so the
    marker is evaluated once without an extra and once per requested
    extra.

    Args:
        req: Parsed requirement whose marker should be evaluated.
        extras: Normalized extras requested by the dependent package.

    Returns:
        True if the requirement applies in the target environment.
    """
    if req.marker is None:
        return True
    if req.marker.evaluate({**TARGET_ENV, "extra": ""}):
        return True
    return any(req.marker.evaluate({**TARGET_ENV, "extra": extra}) for extra in extras)


def _is_sdist(entry: dict[str, Any]) -> bool:
    """Tell whether a release file entry is a source distribution.

    Args:
        entry: One entry of a PyPI ``releases[<version>]`` list.

    Returns:
        True for sdists (by packagetype, or by filename when absent).
    """
    packagetype = entry.get("packagetype")
    if packagetype:
        return packagetype == "sdist"
    filename = entry.get("filename") or ""
    return filename.endswith((".tar.gz", ".zip"))


def _sdist_supports_target(files: list[dict[str, Any]]) -> bool:
    """Tell whether a release has a usable sdist for the target Python.

    The generated resource pins the sdist, so the release must carry at
    least one non-yanked sdist whose ``requires_python`` is absent or
    accepts ``TARGET_ENV["python_full_version"]``.

    Args:
        files: The release's file entries.

    Returns:
        True when such an sdist exists.
    """
    target = Version(TARGET_ENV["python_full_version"])
    for entry in files:
        if not _is_sdist(entry) or entry.get("yanked"):
            continue
        requires_python = entry.get("requires_python")
        if not requires_python:
            return True
        try:
            if SpecifierSet(requires_python).contains(target, prereleases=True):
                return True
        except InvalidSpecifier:
            continue
    return False


def resolve_from_pypi(req: Requirement) -> tuple[str, list[str] | None] | None:
    """Resolve a requirement that the analysis environment did not install.

    Picks the newest final release on PyPI that satisfies the specifier and
    ships an sdist usable on the target Python, and returns its version and
    Requires-Dist metadata.

    Args:
        req: Requirement to resolve.

    Returns:
        (version, requires_dist) or None when nothing on PyPI satisfies it.
    """
    project = fetch_pypi_json(req.name)
    candidates: list[Version] = []
    for raw_version, files in (project.get("releases") or {}).items():
        try:
            parsed = Version(raw_version)
        except InvalidVersion:
            continue
        if parsed.is_prerelease or not files:
            continue
        if any(entry.get("yanked") for entry in files):
            continue
        if not req.specifier.contains(parsed, prereleases=False):
            continue
        if not _sdist_supports_target(files):
            print(
                f"Skipping {req.name} {parsed}: no sdist accepts Python "
                f"{TARGET_ENV['python_full_version']} (requires_python)",
                file=sys.stderr,
            )
            continue
        candidates.append(parsed)
    if not candidates:
        return None
    version = str(max(candidates))
    release = fetch_pypi_json(req.name, version)
    requires: list[str] | None = release.get("info", {}).get("requires_dist")
    return version, requires


def get_package_dependencies(
    package_name: str,
    root_extras: frozenset[str] = frozenset(),
) -> set[str]:
    """Get all dependencies of a package recursively.

    Extras requested by a dependent (e.g. ``dynaconf[yaml]``) are
    propagated so that extras-gated requirements are followed instead of
    being dropped by marker evaluation. Requirements whose marker matches
    the target environment but that the analysis environment did not
    install are resolved from PyPI (see :func:`resolve_from_pypi`).

    Args:
        package_name: Name of the package to analyze.
        root_extras: Extras requested for the root package itself.

    Returns:
        Set of normalized dependency package names.
    """
    dist_map = build_distribution_map()
    normalized_name = normalize_name(package_name)
    dependencies: set[str] = set()
    to_process: set[tuple[str, frozenset[str]]] = {(normalized_name, root_extras)}
    processed: set[tuple[str, frozenset[str]]] = set()

    while to_process:
        current, current_extras = to_process.pop()
        if (current, current_extras) in processed:
            continue
        processed.add((current, current_extras))

        if current in dist_map:
            _, requires = dist_map[current]
        elif current in _RESOLVED_FROM_PYPI:
            _, requires = _RESOLVED_FROM_PYPI[current]
        else:
            continue
        if not requires:
            continue

        for req_str in requires:
            try:
                req = Requirement(req_str)
            except InvalidRequirement:
                continue
            if not _marker_matches(req=req, extras=current_extras):
                continue
            req_name = normalize_name(req.name)
            if req_name not in dist_map and req_name not in _RESOLVED_FROM_PYPI:
                resolved = resolve_from_pypi(req)
                if resolved is None:
                    print(
                        f"Warning: {req_str} (required by {current}) is not installed "
                        "and no PyPI release satisfies it; skipping",
                        file=sys.stderr,
                    )
                    continue
                print(
                    f"Resolved {req_name}=={resolved[0]} from PyPI for the target "
                    f"environment ({req_str}, required by {current})",
                    file=sys.stderr,
                )
                _RESOLVED_FROM_PYPI[req_name] = resolved
            dependencies.add(req_name)
            # Keep both spellings: PEP 685 normalizes extras, but a
            # dependency's marker may use the unnormalized form.
            req_extras = frozenset(
                variant
                for extra in req.extras
                for variant in (extra, normalize_name(extra))
            )
            to_process.add((req_name, req_extras))

    dependencies.discard(normalized_name)
    return dependencies


def generate_resource_stanza(
    package_name: str,
    version: str,
) -> str | None:
    """Generate a Homebrew resource stanza for a package.

    Args:
        package_name: Package name on PyPI.
        version: Package version.

    Returns:
        Resource stanza string, or None if sdist not available.
    """
    try:
        data = fetch_pypi_json(package_name, version)
        info = get_sdist_info(data)
        return RESOURCE_TEMPLATE.format(
            name=package_name,
            url=info.tarball_url,
            sha256=info.tarball_sha256,
        )
    except SystemExit:
        print(
            f"Warning: No sdist for {package_name}=={version}, skipping",
            file=sys.stderr,
        )
        return None


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Homebrew resource stanzas for Python dependencies",
    )
    parser.add_argument(
        "package",
        help="Package name to generate resources for",
    )
    parser.add_argument(
        "--exclude",
        nargs="*",
        default=[],
        help="Package names to exclude (e.g., available as Homebrew formulae)",
    )
    parser.add_argument(
        "--extras",
        default="",
        help="Comma-separated extras of the root package to follow (e.g. mcp)",
    )
    parser.add_argument(
        "--platform-machine",
        default=TARGET_ENV["platform_machine"],
        help="Target platform_machine for marker evaluation (arm64 or x86_64)",
    )
    args = parser.parse_args()

    TARGET_ENV["platform_machine"] = args.platform_machine
    exclude: set[str] = {normalize_name(name) for name in args.exclude}
    main_package = normalize_name(args.package)
    exclude.add(main_package)
    root_extras = frozenset(
        variant
        for extra in args.extras.split(",")
        if extra
        for variant in (extra, normalize_name(extra))
    )

    installed = get_installed_packages()
    dependencies = get_package_dependencies(args.package, root_extras=root_extras)
    installed.update(
        {name: version for name, (version, _) in _RESOLVED_FROM_PYPI.items()},
    )
    to_generate = sorted(dependencies - exclude)

    if not to_generate:
        print("No dependencies to generate resources for", file=sys.stderr)
        sys.exit(1)

    stanzas: list[str] = []
    for dep in to_generate:
        version = installed.get(dep)
        if not version:
            print(f"Warning: {dep} not found in installed packages", file=sys.stderr)
            continue

        stanza = generate_resource_stanza(dep, version)
        if stanza:
            stanzas.append(stanza)

    print("\n".join(stanzas))


if __name__ == "__main__":
    main()
