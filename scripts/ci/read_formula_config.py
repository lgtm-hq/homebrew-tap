#!/usr/bin/env python3
"""Read per-product formula configuration from YAML files."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any

import yaml


def formula_class_name(formula_key: str) -> str:
    """Convert a formula key to a Homebrew class name.

    Args:
        formula_key: Formula identifier (e.g., lintro-full).

    Returns:
        PascalCase class name (e.g., LintroFull).
    """
    return "".join(part.capitalize() for part in formula_key.split("-"))


def load_config(config_path: Path) -> dict[str, Any]:
    """Load a product configuration file.

    Args:
        config_path: Path to the YAML config file.

    Returns:
        Parsed configuration dictionary.
    """
    with config_path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def merge_formula_config(
    product_config: dict[str, Any],
    formula_key: str,
) -> dict[str, Any]:
    """Merge product-level and formula-level configuration.

    Args:
        product_config: Full product YAML config.
        formula_key: Key under the formulas map.

    Returns:
        Merged configuration for the requested formula.
    """
    formulas = product_config.get("formulas", {})
    if formula_key not in formulas:
        msg = f"Formula '{formula_key}' not found in config"
        raise KeyError(msg)

    formula_entry = dict(formulas[formula_key])
    return {
        "product": formula_key,
        "package": product_config.get("package"),
        "source-repo": product_config.get("source-repo"),
        "homepage": product_config.get("homepage"),
        "license": product_config.get("license"),
        "description": formula_entry.pop(
            "description",
            product_config.get("description"),
        ),
        "class-name": formula_entry.pop("class-name", formula_class_name(formula_key)),
        **formula_entry,
    }


def emit_shell(config: dict[str, Any]) -> None:
    """Emit configuration as shell variable assignments.

    Args:
        config: Merged formula configuration.
    """
    for key, value in config.items():
        env_key = key.upper().replace("-", "_")
        if isinstance(value, bool):
            print(f"{env_key}={'true' if value else 'false'}")
        elif isinstance(value, (dict, list)):
            print(f"{env_key}={shlex.quote(json.dumps(value))}")
        elif value is None:
            print(f'{env_key}=""')
        else:
            print(f"{env_key}={shlex.quote(str(value))}")


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Read formula product config")
    parser.add_argument("config_path", type=Path, help="Path to formulas/*.yml")
    parser.add_argument(
        "--formula-key",
        help="Specific formula key under formulas:",
    )
    parser.add_argument(
        "--list-formulas",
        action="store_true",
        help="List formula keys in the config file",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output merged config as JSON",
    )
    parser.add_argument(
        "--shell",
        action="store_true",
        help="Output merged config as shell assignments",
    )
    args = parser.parse_args()

    product_config = load_config(args.config_path)

    if args.list_formulas:
        formulas = product_config.get("formulas", {})
        for key in formulas:
            print(key)
        return

    if not args.formula_key:
        print(
            "Error: --formula-key is required unless --list-formulas", file=sys.stderr
        )
        sys.exit(1)

    merged = merge_formula_config(product_config, args.formula_key)

    if args.shell:
        emit_shell(merged)
    elif args.json:
        print(json.dumps(merged, indent=2))
    else:
        print(json.dumps(merged))


if __name__ == "__main__":
    main()
