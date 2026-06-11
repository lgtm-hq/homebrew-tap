#!/usr/bin/env python3
"""Render Homebrew formula files from templates."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def read_file_content(path: str) -> str:
    """Read content from file or stdin if path is '-'.

    Args:
        path: File path or '-' for stdin.

    Returns:
        File content as a string.
    """
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def render_template(template: str, replacements: dict[str, str]) -> str:
    """Replace placeholders in a template string.

    Args:
        template: Template content with {{KEY}} placeholders.
        replacements: Mapping of placeholder keys to values.

    Returns:
        Rendered template string.
    """
    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
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

    template = Path(args.template).read_text(encoding="utf-8")
    replacements: dict[str, str] = {}

    for item in args.replace:
        key, _, value = item.partition("=")
        replacements[key] = value

    for item in args.replace_file:
        key, _, path = item.partition("=")
        replacements[key] = read_file_content(path).rstrip()

    rendered = render_template(template, replacements)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")
        print(f"Formula written to {args.output}", file=sys.stderr)
    else:
        print(rendered)


if __name__ == "__main__":
    main()
