#!/usr/bin/env python3
"""Render Homebrew formula files from templates."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PLACEHOLDER_PATTERN = re.compile(r"\{\{[^}]+\}\}")


def read_file_content(path: str) -> str:
    """Read content from file or stdin if path is '-'.

    Args:
        path: File path or '-' for stdin.

    Returns:
        File content as a string.

    Raises:
        RuntimeError: If the file cannot be read.
    """
    try:
        if path == "-":
            return sys.stdin.read()
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        msg = f"Template or replacement file not found: {path}"
        raise RuntimeError(msg) from exc
    except PermissionError as exc:
        msg = f"Permission denied reading file: {path}"
        raise RuntimeError(msg) from exc
    except UnicodeDecodeError as exc:
        msg = f"Failed to decode file as UTF-8: {path}"
        raise RuntimeError(msg) from exc
    except OSError as exc:
        msg = f"Failed to read file: {path}"
        raise RuntimeError(msg) from exc


def parse_replacement(item: str, *, kind: str) -> tuple[str, str]:
    """Parse a KEY=VALUE replacement argument.

    Args:
        item: Replacement argument string.
        kind: Argument kind label for error messages.

    Returns:
        Parsed key and value tuple.

    Raises:
        SystemExit: If the argument is malformed.
    """
    if "=" not in item:
        print(f"Invalid {kind} argument (missing '='): {item}", file=sys.stderr)
        sys.exit(1)

    key, _, value = item.partition("=")
    if not key or not value:
        print(f"Invalid {kind} argument (empty key or value): {item}", file=sys.stderr)
        sys.exit(1)

    return key, value


def render_template(template: str, replacements: dict[str, str]) -> str:
    """Replace placeholders in a template string.

    Args:
        template: Template content with {{KEY}} placeholders.
        replacements: Mapping of placeholder keys to values.

    Returns:
        Rendered template string.

    Raises:
        ValueError: If any placeholders remain unreplaced.
    """
    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)

    unreplaced = sorted(set(PLACEHOLDER_PATTERN.findall(rendered)))
    if unreplaced:
        msg = f"Unreplaced template placeholders: {', '.join(unreplaced)}"
        raise ValueError(msg)

    return rendered


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Render Homebrew formula template")
    parser.add_argument("--template", required=True, help="Path to template file")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    parser.add_argument(
        "--replace",
        action="append",
        default=[],
        help="Replacement KEY=VALUE (may be repeated)",
    )
    parser.add_argument(
        "--replace-file",
        action="append",
        default=[],
        help="Read replacements from file KEY=path (may be repeated)",
    )
    args = parser.parse_args()

    try:
        template = read_file_content(args.template)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    replacements: dict[str, str] = {}

    for item in args.replace:
        key, value = parse_replacement(item, kind="--replace")
        replacements[key] = value

    for item in args.replace_file:
        key, path = parse_replacement(item, kind="--replace-file")
        try:
            replacements[key] = read_file_content(path).rstrip()
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            sys.exit(1)

    try:
        rendered = render_template(template, replacements)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_path = Path(args.output)
        try:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(rendered, encoding="utf-8")
        except (PermissionError, OSError) as exc:
            print(
                f"Failed to write formula to {output_path}: {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"Formula written to {args.output}", file=sys.stderr)
    else:
        print(rendered)


if __name__ == "__main__":
    main()
