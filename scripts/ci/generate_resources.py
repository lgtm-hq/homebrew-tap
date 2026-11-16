#!/usr/bin/env python3
"""Generate Homebrew resource stanzas for Python package dependencies.

This is a modern replacement for homebrew-pypi-poet that:
- Uses importlib.metadata instead of deprecated pkg_resources
- Uses pypi.org API directly (via pypi_utils)
- Generates resource stanzas compatible with Homebrew formulae

Usage:
    # Describe the environment the package was installed into, then generate
    # resources for it (the walk itself runs on any Python with `packaging`)
    <venv>/bin/python -I probe_analysis_env.py > env.json
    python3 generate_resources.py lintro --analysis-env env.json \
        --python-version 3.13

    # Exclude specific packages (e.g., already available as Homebrew formulae)
    python3 generate_resources.py lintro --analysis-env env.json \
        --python-version 3.13 --exclude bandit black mypy ruff yamllint

    # Follow the root package's extras and resolve for an Intel Mac
    python3 generate_resources.py lintro --analysis-env env.json \
        --python-version 3.13 --extras mcp --platform-machine x86_64

The walk reads installed distributions and Python details only from the
analysis environment described by --analysis-env, never from the interpreter
it runs under: the host's own packages and Python version must not decide
what a formula pins.

Requirements that the analysis environment did not install (a dependency
gated on a marker that is false where the analysis ran, e.g. macOS x86_64
only) are resolved from PyPI: the newest final release satisfying the
specifier is pinned and its own requirements are walked the same way.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from importlib.metadata import distributions
from pathlib import Path
from typing import Any

from packaging.markers import Marker
from packaging.requirements import InvalidRequirement, Requirement
from packaging.specifiers import InvalidSpecifier, SpecifierSet
from packaging.version import InvalidVersion, Version

from pypi_utils import fetch_pypi_json, get_sdist_info, normalize_name

# Every PEP 508 marker variable. All of them are set explicitly for each
# run: a variable left out would be filled in by `packaging` from the
# interpreter the walk runs under, which is not the formula's.
MARKER_KEYS: frozenset[str] = frozenset(
    {
        "implementation_name",
        "implementation_version",
        "os_name",
        "platform_machine",
        "platform_python_implementation",
        "platform_release",
        "platform_system",
        "platform_version",
        "python_full_version",
        "python_version",
        "sys_platform",
    },
)

# Marker variables that describe the kernel of one particular machine.
KERNEL_MARKER_KEYS: tuple[str, ...] = ("platform_release", "platform_version")
# `packaging` keeps a parsed marker as a tree in this attribute: a list of
# comparisons (3-tuples of operand, operator, operand), the strings "and" and
# "or", and nested lists for parentheses. It has had this shape since
# packaging 21. It is read by name so that a version without it is refused
# instead of guessed at (see _assume_kernel).
_MARKER_TREE_ATTRIBUTE = "_markers"
# A parsed comparison is (operand, operator, operand).
_COMPARISON_PARTS = 3

# What a formula's target always is, whatever machine generates it: macOS.
# platform_machine is set per run (--platform-machine): arm64 for Apple
# silicon formulas, x86_64 for the Intel branch of a binary formula.
TARGET_PLATFORM: dict[str, str] = {
    "sys_platform": "darwin",
    "os_name": "posix",
    "platform_system": "Darwin",
    "platform_machine": "arm64",
}

# Marker environment for this run, filled by load_analysis_env(): the
# analysis environment's Python values with TARGET_PLATFORM on top.
TARGET_ENV: dict[str, str] = {}

# Directories holding the analysis environment's distributions, filled by
# load_analysis_env(). Nothing else is ever searched.
_ANALYSIS_SITE_PATHS: list[str] = []

# Requirements not installed in the analysis environment, resolved from
# PyPI metadata: normalized name -> (version, requires_dist).
_RESOLVED_FROM_PYPI: dict[str, tuple[str, list[str] | None]] = {}
# The requirement that produced each resolution, for conflict messages:
# normalized name -> (requirement string, dependent).
_RESOLVED_BY: dict[str, tuple[str, str]] = {}

# Template for a single resource stanza
RESOURCE_TEMPLATE = """  resource "{name}" do
    url "{url}"
    sha256 "{sha256}"
  end
"""


def load_analysis_env(
    path: Path,
    python_version: str,
    platform_machine: str,
) -> None:
    """Read the analysis environment's description and set the run's targets.

    Fills ``TARGET_ENV`` and ``_ANALYSIS_SITE_PATHS`` from the JSON that
    probe_analysis_env.py printed under the analysis interpreter.

    Args:
        path: The JSON file.
        python_version: The formula's MAJOR.MINOR; the environment must run it.
        platform_machine: Target platform_machine (arm64 or x86_64).
    """
    try:
        described = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        sys.exit(f"Cannot read the analysis environment description {path}: {error}")
    if not isinstance(described, dict):
        sys.exit(f"{path} does not describe an analysis environment")

    site_paths = described.get("site_paths")
    if (
        not isinstance(site_paths, list)
        or not site_paths
        or not all(isinstance(entry, str) and entry for entry in site_paths)
    ):
        sys.exit(f"{path} lists no site_paths for the analysis environment")
    missing_dirs = [entry for entry in site_paths if not Path(entry).is_dir()]
    if missing_dirs:
        sys.exit(f"{path} names site_paths that do not exist: {missing_dirs}")

    marker_env = described.get("marker_env")
    if not isinstance(marker_env, dict):
        sys.exit(f"{path} carries no marker_env for the analysis environment")
    absent = sorted(
        key
        for key in MARKER_KEYS
        if not isinstance(marker_env.get(key), str)
        # Release and version may legitimately be empty strings.
        or (not marker_env[key] and key not in {"platform_release", "platform_version"})
    )
    if absent:
        sys.exit(f"{path} is missing marker values: {', '.join(absent)}")
    if marker_env["python_version"] != python_version:
        sys.exit(
            f"The analysis environment runs Python {marker_env['python_version']}, "
            f"but --python-version is {python_version}",
        )
    full_version = marker_env["python_full_version"]
    if not re.fullmatch(
        rf"{re.escape(python_version)}\.\d+(?:(?:a|b|rc)\d+)?\+?",
        full_version,
    ):
        # Caught here, not at first use: an unreadable value would make
        # every python_full_version marker quietly evaluate false. (A
        # pre-release or local build is compared correctly from packaging
        # 24.2 on, which is the project's floor.)
        sys.exit(
            f"{path} gives python_full_version {full_version!r}, which is not "
            f"a Python {python_version} release",
        )

    target = {key: marker_env[key] for key in MARKER_KEYS}
    # The target's kernel is unknown: a formula serves several macOS
    # releases and the generator may not be macOS at all. A marker that
    # mentions either value is never evaluated with it (_marker_matches
    # decides it without, or refuses it); they are set only so that
    # `packaging` does not fill them in from the walk's own interpreter.
    for key in KERNEL_MARKER_KEYS:
        target[key] = ""
    target.update(TARGET_PLATFORM)
    target["platform_machine"] = platform_machine

    TARGET_ENV.clear()
    TARGET_ENV.update(target)
    _ANALYSIS_SITE_PATHS[:] = site_paths


def build_distribution_map() -> dict[str, tuple[str, list[str] | None]]:
    """Build a map of the distributions installed in the analysis environment.

    Returns:
        Dictionary mapping normalized package names to (version, requires) tuples.
    """
    if not _ANALYSIS_SITE_PATHS:
        # An empty path list would make importlib search the walk's own
        # interpreter, which is exactly what must never happen.
        sys.exit("The analysis environment has not been loaded")
    dist_map: dict[str, tuple[str, list[str] | None]] = {}
    for dist in distributions(path=list(_ANALYSIS_SITE_PATHS)):
        name = dist.metadata["Name"]
        version = dist.metadata["Version"]
        if name and version:
            normalized = normalize_name(name)
            if normalized in dist_map:
                # The first directory wins, as it does on import.
                continue
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


def _evaluate(marker: Marker, extras: frozenset[str]) -> bool:
    """Evaluate a marker for the target environment and the requested extras.

    Extras-gated requirements (e.g. ``ruamel.yaml ; extra == "yaml"``)
    only match when the dependent was requested with that extra, so the
    marker is evaluated once without an extra and once per requested
    extra.

    Args:
        marker: Marker to evaluate.
        extras: Normalized extras requested by the dependent package.

    Returns:
        True if the marker holds in the target environment.
    """
    if marker.evaluate({**TARGET_ENV, "extra": ""}):
        return True
    return any(marker.evaluate({**TARGET_ENV, "extra": extra}) for extra in extras)


def _reads_kernel(comparison: tuple[Any, ...]) -> bool:
    """Tell whether evaluating a parsed comparison reads a kernel value.

    This mirrors how `packaging` evaluates a comparison: if the left operand
    is a variable, its name is looked up in the environment and the right
    operand is taken as text; otherwise the *right* operand's text is the
    name looked up, whether it was written as a variable or as a quoted
    string. So ``"25.1.0" == "platform_release"`` reads the kernel release,
    while ``platform_machine != "platform_release"`` only compares with the
    text.

    Args:
        comparison: One (operand, operator, operand) tuple of a marker tree.

    Returns:
        True if the name looked up is platform_release or platform_version.
    """
    left, right = comparison[0], comparison[-1]
    looked_up = left if type(left).__name__ == "Variable" else right
    return getattr(looked_up, "value", None) in KERNEL_MARKER_KEYS


def _assume_kernel(
    tree: Any, stand_in: tuple[Any, ...]
) -> tuple[list[Any], int] | None:
    """Rebuild a marker tree with every kernel comparison replaced.

    The lists are built anew and the other comparisons are shared, so the
    original tree is never touched. The marker is deliberately not copied
    as an object: from packaging 26.2 a copied marker is written out as
    text and parsed again.

    Args:
        tree: A parsed marker tree (see _MARKER_TREE_ATTRIBUTE).
        stand_in: The parsed comparison to put in place of each kernel one.

    Returns:
        (the rebuilt tree, how many comparisons were replaced), or None when
        the tree does not have the expected shape and nothing can be said.
    """
    if not isinstance(tree, list):
        return None
    rebuilt: list[Any] = []
    replaced = 0
    for node in tree:
        if isinstance(node, list):
            nested = _assume_kernel(node, stand_in)
            if nested is None:
                return None
            rebuilt.append(nested[0])
            replaced += nested[1]
        elif isinstance(node, tuple) and len(node) == _COMPARISON_PARTS:
            if _reads_kernel(node):
                rebuilt.append(stand_in)
                replaced += 1
            else:
                rebuilt.append(node)
        elif node in ("and", "or"):
            rebuilt.append(node)
        else:
            return None
    return rebuilt, replaced


def _marker_matches(
    req: Requirement,
    extras: frozenset[str],
    req_str: str,
    dependent: str,
) -> bool:
    """Tell whether a requirement applies in the target environment.

    The kernel release and version of the Macs a formula will be installed
    on are not known when it is generated, so a comparison that reads
    ``platform_release`` or ``platform_version`` has no answer. The parsed
    marker is rebuilt twice: once with every such comparison replaced by one
    that is true, once by one that is false. A marker combines comparisons
    with ``and`` and ``or`` only (there is no negation), so every other
    combination lies between those two. If both give the same answer, the
    kernel does not decide the marker (it is not for macOS, its extra was
    not requested, another clause already holds) and that answer is used.
    If they differ, guessing would silently add or drop a dependency, and
    generation stops.

    The kernel comparisons themselves are never evaluated, and the marker
    is never handled as text.

    Args:
        req: Parsed requirement whose marker should be evaluated.
        extras: Normalized extras requested by the dependent package.
        req_str: The requirement's original Requires-Dist text.
        dependent: Package that declares it.

    Returns:
        True if the requirement applies in the target environment.
    """
    if req.marker is None:
        return True
    tree = getattr(req.marker, _MARKER_TREE_ATTRIBUTE, None)
    answers: list[bool] = []
    # os_name is always "posix" for the target (TARGET_PLATFORM).
    for assumption in ('os_name == "posix"', 'os_name != "posix"'):
        candidate = Marker(assumption)
        stand_in = getattr(candidate, _MARKER_TREE_ATTRIBUTE, [None])[0]
        rebuilt = _assume_kernel(tree, stand_in)
        if rebuilt is None or not isinstance(stand_in, tuple):
            sys.exit(
                f"Cannot decide '{req_str}' (required by {dependent}): this "
                "version of packaging does not expose the parsed marker, so "
                "whether it reads the kernel cannot be told",
            )
        if rebuilt[1] == 0:
            return _evaluate(marker=req.marker, extras=extras)
        setattr(candidate, _MARKER_TREE_ATTRIBUTE, rebuilt[0])
        answers.append(_evaluate(marker=candidate, extras=extras))
    if answers[0] != answers[1]:
        sys.exit(
            f"Cannot decide '{req_str}' (required by {dependent}): its marker "
            "depends on platform_release or platform_version, and the kernel "
            "of the Macs the formula installs on is not known at generation "
            "time",
        )
    return answers[0]


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


def _target_python() -> Version:
    """Give the target Python's release for ``requires_python`` checks.

    pip compares a release's ``Requires-Python`` with the interpreter's
    major, minor and micro numbers only, so a release candidate (3.14.0rc1)
    counts as 3.14.0 and a local build suffix (3.13.5+) is ignored. The same
    numbers are used here so the walk accepts what pip accepts.

    Returns:
        The release as a version.
    """
    full_version = TARGET_ENV["python_full_version"]
    release = re.match(r"\d+(?:\.\d+){0,2}", full_version)
    if release is None:
        sys.exit(f"Cannot read a Python release from {full_version!r}")
    return Version(release.group(0))


def _sdist_supports_target(files: list[dict[str, Any]]) -> bool:
    """Tell whether a release has a usable sdist for the target Python.

    The generated resource pins the sdist, so the release must carry at
    least one non-yanked sdist whose ``requires_python`` is absent or
    accepts the target Python's release (see :func:`_target_python`).

    Args:
        files: The release's file entries.

    Returns:
        True when such an sdist exists.
    """
    target = _target_python()
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


def _check_resolved_pin(req: Requirement, req_str: str, dependent: str) -> None:
    """Fail closed when a cached PyPI resolution does not satisfy a later pin.

    The cache is keyed by project name; reusing the first resolved version
    for an incompatible specifier would depend on traversal order and pin a
    version some dependent rejects.

    Args:
        req: Parsed requirement being checked.
        req_str: Its original Requires-Dist text.
        dependent: Package that declares it.
    """
    name = normalize_name(req.name)
    version, _ = _RESOLVED_FROM_PYPI[name]
    if req.specifier.contains(Version(version), prereleases=False):
        return
    first_req, first_dependent = _RESOLVED_BY[name]
    sys.exit(
        f"Conflicting pins for {name}: resolved {name}=={version} for "
        f"'{first_req}' (required by {first_dependent}), but '{req_str}' "
        f"(required by {dependent}) does not accept it",
    )


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
            if not _marker_matches(
                req=req,
                extras=current_extras,
                req_str=req_str,
                dependent=current,
            ):
                continue
            req_name = normalize_name(req.name)
            if req_name in _RESOLVED_FROM_PYPI:
                _check_resolved_pin(req=req, req_str=req_str, dependent=current)
            elif req_name not in dist_map:
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
                _RESOLVED_BY[req_name] = (req_str, current)
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
        "--analysis-env",
        required=True,
        type=Path,
        help=(
            "JSON printed by probe_analysis_env.py under the interpreter the "
            "package was installed with; the only source of installed "
            "distributions and Python marker values"
        ),
    )
    parser.add_argument(
        "--platform-machine",
        default=TARGET_PLATFORM["platform_machine"],
        help="Target platform_machine for marker evaluation (arm64 or x86_64)",
    )
    parser.add_argument(
        "--python-version",
        required=True,
        help=(
            "Python MAJOR.MINOR the formula installs with; the analysis "
            "environment must run it"
        ),
    )
    args = parser.parse_args()

    if not re.fullmatch(r"\d+\.\d+", args.python_version):
        parser.error(
            f"--python-version must be MAJOR.MINOR (got {args.python_version!r})",
        )
    load_analysis_env(
        path=args.analysis_env,
        python_version=args.python_version,
        platform_machine=args.platform_machine,
    )
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
