#!/usr/bin/env python3
"""Validate Homebrew formula descriptions against FormulaAudit/Desc."""

from __future__ import annotations

import argparse
import sys

from read_formula_config import formula_class_name


def audit_name_candidates(formula_key: str) -> tuple[str, ...]:
    """Return name variants Homebrew treats as the formula name.

    Args:
        formula_key: Formula identifier (e.g., winnow, lintro-full).

    Returns:
        Unique candidate prefixes to check, longest first.
    """
    class_name = formula_class_name(formula_key=formula_key)
    spaced = formula_key.replace("-", " ")
    candidates = (
        class_name,
        formula_key,
        spaced,
        class_name.lower(),
    )
    seen: set[str] = set()
    ordered: list[str] = []
    for candidate in candidates:
        lowered = candidate.lower()
        if lowered not in seen:
            seen.add(lowered)
            ordered.append(candidate)
    return tuple(sorted(ordered, key=len, reverse=True))


def description_starts_with_formula_name(
    description: str,
    formula_key: str,
) -> bool:
    """Return whether a description violates FormulaAudit/Desc.

    Args:
        description: Proposed formula desc string.
        formula_key: Formula key under formulas: in product config.

    Returns:
        True when the description starts with the formula name.
    """
    desc = description.strip()
    if not desc:
        return False

    desc_lower = desc.lower()
    for name in audit_name_candidates(formula_key=formula_key):
        name_lower = name.lower()
        if not desc_lower.startswith(name_lower):
            continue
        suffix = desc[len(name) :]
        if not suffix or suffix[0] in " \t:-—.,;":
            return True
    return False


def validate_formula_description(description: str, formula_key: str) -> None:
    """Raise when a description violates FormulaAudit/Desc.

    Args:
        description: Proposed formula desc string.
        formula_key: Formula key under formulas: in product config.

    Raises:
        ValueError: When the description starts with the formula name.
    """
    if description_starts_with_formula_name(
        description=description,
        formula_key=formula_key,
    ):
        msg = (
            f"Description must not start with formula name '{formula_key}' "
            "(FormulaAudit/Desc). Update the product or formula description in "
            f"formulas/*.yml."
        )
        raise ValueError(msg)


def main() -> None:
    """Validate a formula description from the command line."""
    parser = argparse.ArgumentParser(
        description="Validate formula descriptions for FormulaAudit/Desc",
    )
    parser.add_argument("formula_key", help="Formula key (e.g., winnow)")
    parser.add_argument("description", help="Proposed desc string")
    args = parser.parse_args()

    try:
        validate_formula_description(
            description=args.description,
            formula_key=args.formula_key,
        )
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
