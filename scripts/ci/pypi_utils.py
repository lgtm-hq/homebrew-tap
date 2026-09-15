#!/usr/bin/env python3
"""Shared PyPI API utilities for Homebrew formula generation."""

import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, NamedTuple

# PyPI API base URL (only https is allowed)
PYPI_BASE_URL = "https://pypi.org/pypi"
# PyPI integrity API (PEP 740 provenance), https only
PYPI_INTEGRITY_URL = "https://pypi.org/integrity"


class PackageInfo(NamedTuple):
    """Information about a package release."""

    version: str
    tarball_url: str
    tarball_sha256: str


class WheelInfo(NamedTuple):
    """Information about a wheel file."""

    url: str
    sha256: str


def fetch_pypi_json(
    package: str,
    version: str | None = None,
) -> dict[str, Any]:
    """Fetch package JSON from PyPI.

    Args:
        package: Package name on PyPI.
        version: Specific version to fetch, or None for latest.

    Returns:
        PyPI JSON response as dictionary.
    """
    fixture_dir = os.environ.get("PYPI_FIXTURE_DIR")
    if fixture_dir:
        # <package>-<version>.json for a release, <package>.json for the
        # project document (releases map); fixture mode never reaches PyPI.
        fixture_name = f"{package}-{version}.json" if version else f"{package}.json"
        fixture_path = Path(fixture_dir) / fixture_name
        if fixture_path.is_file():
            with fixture_path.open(encoding="utf-8") as handle:
                result: dict[str, Any] = json.load(handle)
                return result
        spec = f"{package}=={version}" if version else package
        msg = (
            f"Missing PyPI fixture for {spec} "
            f"under {fixture_dir} (expected {fixture_path.name})"
        )
        print(msg, file=sys.stderr)
        sys.exit(1)

    if version:
        url = f"{PYPI_BASE_URL}/{package}/{version}/json"
    else:
        url = f"{PYPI_BASE_URL}/{package}/json"

    try:
        # Safe: URL from hardcoded PYPI_BASE_URL (https://pypi.org/pypi)
        # nosemgrep: dynamic-urllib-use-detected
        with urllib.request.urlopen(url, timeout=30) as response:  # nosec B310
            result: dict[str, Any] = json.load(response)
            return result
    except (OSError, ValueError) as exc:
        print(f"Error fetching {url}: {exc}", file=sys.stderr)
        sys.exit(1)


def get_latest_version(package: str) -> str:
    """Get the latest version of a package from PyPI.

    Args:
        package: Package name on PyPI.

    Returns:
        Latest version string.
    """
    data = fetch_pypi_json(package)
    version: str = data["info"]["version"]
    return version


def get_sdist_info(data: dict[str, Any]) -> PackageInfo:
    """Extract source distribution info from PyPI JSON.

    Args:
        data: PyPI JSON response.

    Returns:
        PackageInfo with version, tarball URL, and SHA256.
    """
    version = data["info"]["version"]
    for url_info in data.get("urls", []):
        if url_info.get("packagetype") == "sdist":
            return PackageInfo(
                version=version,
                tarball_url=url_info["url"],
                tarball_sha256=url_info["digests"]["sha256"],
            )

    print("Error: No source distribution found", file=sys.stderr)
    sys.exit(1)


def find_universal_wheel(data: dict[str, Any]) -> WheelInfo | None:
    """Find a universal wheel (py3-none-any).

    Args:
        data: PyPI JSON response.

    Returns:
        WheelInfo if found, None otherwise.
    """
    for url_info in data.get("urls", []):
        if "py3-none-any.whl" in url_info.get("filename", ""):
            return WheelInfo(
                url=url_info["url"],
                sha256=url_info["digests"]["sha256"],
            )
    return None


def find_macos_wheel(
    data: dict[str, Any],
    arch: str,
    python_version: str = "313",
) -> WheelInfo | None:
    """Find a macOS wheel for specific architecture.

    Args:
        data: PyPI JSON response.
        arch: Architecture string (e.g., "arm64", "x86_64").
        python_version: Python version without dots (e.g., "313" for 3.13).

    Returns:
        WheelInfo if found, None otherwise.
    """
    cpython_tag = f"cp{python_version}-cp{python_version}"
    for url_info in data.get("urls", []):
        filename = url_info.get("filename", "")
        if f"{cpython_tag}-macosx" in filename and arch in filename:
            return WheelInfo(
                url=url_info["url"],
                sha256=url_info["digests"]["sha256"],
            )
    return None


def fetch_pypi_provenance(
    package: str,
    version: str,
    filename: str,
) -> dict[str, Any] | None:
    """Fetch the PEP 740 provenance PyPI stores for one distribution file.

    Under ``PYPI_FIXTURE_DIR`` the provenance is read from
    ``<package>-<version>-<filename>.provenance.json``; a missing fixture
    means "no provenance", mirroring PyPI's 404.

    Args:
        package: PyPI project name.
        version: Release version.
        filename: Distribution filename.

    Returns:
        Parsed provenance object, or None when PyPI has none.
    """
    fixture_dir = os.environ.get("PYPI_FIXTURE_DIR")
    if fixture_dir:
        fixture_name = f"{package}-{version}-{filename}.provenance.json"
        fixture_path = Path(fixture_dir) / fixture_name
        if not fixture_path.is_file():
            return None
        with fixture_path.open(encoding="utf-8") as handle:
            result: dict[str, Any] = json.load(handle)
            return result

    url = f"{PYPI_INTEGRITY_URL}/{package}/{version}/{filename}/provenance"
    try:
        # Safe: URL from hardcoded PYPI_INTEGRITY_URL (https://pypi.org/integrity)
        # nosemgrep: dynamic-urllib-use-detected
        with urllib.request.urlopen(url, timeout=30) as response:  # nosec B310
            result = json.load(response)
            return result
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        print(f"Error fetching {url}: {exc}", file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError) as exc:
        print(f"Error fetching {url}: {exc}", file=sys.stderr)
        sys.exit(1)


def _publisher_errors(
    index: int,
    publisher: dict[str, Any],
    repo: str,
    workflow: str | None,
) -> list[str]:
    """Compare one bundle's Trusted Publisher with the expected identity.

    Args:
        index: Bundle position, for messages.
        publisher: The bundle's ``publisher`` object.
        repo: Expected GitHub repository (owner/repo).
        workflow: Expected workflow filename, if enforced.

    Returns:
        Mismatch descriptions; empty when the publisher matches.
    """
    kind = publisher.get("kind")
    if kind != "GitHub":
        return [f"bundle {index}: publisher kind {kind!r} is not GitHub"]
    errors: list[str] = []
    repository = publisher.get("repository")
    if repository != repo:
        errors.append(
            f"bundle {index}: publisher repository {repository!r} != {repo!r}",
        )
    publisher_workflow = publisher.get("workflow")
    if workflow and publisher_workflow != workflow:
        errors.append(
            f"bundle {index}: publisher workflow {publisher_workflow!r} "
            f"!= {workflow!r}",
        )
    return errors


def _subject_matches(
    index: int,
    attestations: list[dict[str, Any]],
    filename: str,
    sha256: str,
    errors: list[str],
) -> bool:
    """Check whether any attestation subject names the file with the digest.

    Args:
        index: Bundle position, for messages.
        attestations: The bundle's ``attestations`` list.
        filename: Distribution filename the subject must name.
        sha256: Expected subject digest.
        errors: Collector for unreadable statements.

    Returns:
        True when a subject matches filename and digest.
    """
    matched = False
    for attestation in attestations:
        try:
            raw_statement = attestation["envelope"]["statement"]
            statement = json.loads(base64.b64decode(raw_statement))
        except (KeyError, TypeError, ValueError) as exc:
            errors.append(f"bundle {index}: unreadable attestation statement ({exc})")
            continue
        for subject in statement.get("subject") or []:
            digest = (subject.get("digest") or {}).get("sha256")
            if subject.get("name") == filename and digest == sha256:
                matched = True
    return matched


def provenance_errors(
    data: dict[str, Any],
    filename: str,
    sha256: str,
    repo: str,
    workflow: str | None = None,
) -> list[str]:
    """Compare PEP 740 provenance with the digest and publisher the tap expects.

    Args:
        data: Provenance object from :func:`fetch_pypi_provenance`.
        filename: Distribution filename the subject must name.
        sha256: Expected subject digest.
        repo: Expected GitHub Trusted Publisher repository (owner/repo).
        workflow: Expected Trusted Publisher workflow filename, if enforced.

    Returns:
        Human-readable mismatch descriptions; empty when everything agrees.
    """
    bundles = data.get("attestation_bundles") or []
    if not bundles:
        return ["provenance has no attestation bundles"]

    errors: list[str] = []
    subject_matched = False
    for index, bundle in enumerate(bundles):
        publisher_errors = _publisher_errors(
            index=index,
            publisher=bundle.get("publisher") or {},
            repo=repo,
            workflow=workflow,
        )
        errors.extend(publisher_errors)
        if publisher_errors and publisher_errors[0].endswith("is not GitHub"):
            continue
        if _subject_matches(
            index=index,
            attestations=bundle.get("attestations") or [],
            filename=filename,
            sha256=sha256,
            errors=errors,
        ):
            subject_matched = True

    if not subject_matched:
        errors.append(f"no attestation subject names {filename} with sha256 {sha256}")
    return errors
