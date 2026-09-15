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


def merge_provenance(
    product_value: Any,
    formula_value: Any,
    *,
    product_has_key: bool,
    formula_has_key: bool,
) -> Any:
    """Merge the product- and formula-level provenance blocks.

    Args:
        product_value: Product-level ``provenance`` value (None when absent).
        formula_value: Formula-level ``provenance`` value (None when absent).
        product_has_key: Whether the product document has the key at all.
        formula_has_key: Whether the formula entry has the key at all.

    Returns:
        The merged mapping when every present value is a mapping; otherwise
        the offending non-mapping value (an empty mapping stays empty, null
        stays None) so callers can fail. None when neither level has the key.
    """
    if not product_has_key and not formula_has_key:
        return None
    merged: dict[str, Any] = {}
    levels = ((product_has_key, product_value), (formula_has_key, formula_value))
    for present, value in levels:
        if not present:
            continue
        if not isinstance(value, dict):
            return value
        merged.update(value)
    return merged


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
    # Provenance identities are a product property (one release pipeline
    # signs every artifact); a formula entry may still override single keys.
    # None means the key is absent at both levels (checks not adopted); a
    # present-but-empty, null or non-mapping value is passed through so the
    # generators reject it instead of treating it as absent.
    provenance_present = "provenance" in product_config or "provenance" in formula_entry
    provenance = merge_provenance(
        product_config.get("provenance"),
        formula_entry.pop("provenance", None),
        product_has_key="provenance" in product_config,
        formula_has_key="provenance" in formulas[formula_key],
    )
    merged: dict[str, Any] = {
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
    # Only emit the key when some level declares it, so consumers can tell
    # "not adopted" (key absent) from "present but null/empty/invalid".
    if provenance_present:
        merged["provenance"] = provenance
    return merged


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
