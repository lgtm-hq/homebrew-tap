#!/usr/bin/env python3
"""Generate the Homebrew tap landing page from the repo's own metadata.

The page is built from `formulas/*.yml` (grouping, descriptions, deps) and the
live version parsed from each `Formula/*.rb`, so it can never drift from what the
tap actually ships. Presentation copy is derived here, not stored in the config.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

PLACEHOLDER_PATTERN = re.compile(r"\{\{[^}]+\}\}")
PYPI_SDIST_PATTERN = re.compile(
    r"files\.pythonhosted\.org/[^\"\s]+/([^\"/\s]+)\.tar\.gz",
)
VERSION_LINE_PATTERN = re.compile(r'^\s*version\s+"([^\"]+)"', re.MULTILINE)


@dataclass
class Variant:
    """A single installable formula within a product."""

    name: str
    formula_type: str
    version: str
    tags: list[str]
    install_cmd: str
    label: str | None = None
    note: str | None = None


@dataclass
class Product:
    """A tool in the tap, with one or more install variants."""

    name: str
    description: str
    version: str
    variants: list[Variant] = field(default_factory=list)


def read_formula_version(formula_path: Path) -> str:
    """Parse the shipping version from a generated formula file.

    Binary formulas carry an explicit ``version "X"``; PyPI formulas embed the
    version in their sdist URL filename (``<package>-<version>.tar.gz``).

    Args:
        formula_path: Path to a ``Formula/<name>.rb`` file.

    Returns:
        The version string (without a leading ``v``).

    Raises:
        ValueError: If no version can be determined.
    """
    text = formula_path.read_text(encoding="utf-8")

    match = VERSION_LINE_PATTERN.search(text)
    if match:
        return match.group(1)

    sdist = PYPI_SDIST_PATTERN.search(text)
    if sdist:
        # e.g. "winnow_media-0.2.0" -> "0.2.0"
        return sdist.group(1).rsplit("-", 1)[-1]

    msg = f"Could not determine version from {formula_path}"
    raise ValueError(msg)


def derive_tags(entry: dict, python_version: str | None) -> list[str]:
    """Derive display tags for a formula from its config entry.

    Args:
        entry: A single formula entry from a product config.
        python_version: The formula's Python version, if any.

    Returns:
        Ordered display tags (type, arches/deps, python version).
    """
    formula_type = entry.get("type", "")
    if formula_type == "binary":
        tags = ["binary"]
        arches = entry.get("binary-names", {})
        if {"arm64", "x86_64"} <= set(arches):
            tags.append("arm64 · x86_64")
        tags.append("zero deps")
        return tags

    tags = ["pypi"]
    deps = entry.get("homebrew-deps") or []
    if deps:
        tags.append(f"{len(deps)} tools")
    if python_version:
        tags.append(f"python@{python_version}")
    return tags


def build_products(formulas_dir: Path, formula_dir: Path) -> list[Product]:
    """Read every product config and assemble the catalogue.

    Args:
        formulas_dir: Directory of ``*.yml`` product configs.
        formula_dir: Directory of generated ``*.rb`` formulae.

    Returns:
        Products sorted by name, each with ordered install variants.
    """
    products: list[Product] = []

    for config_path in sorted(formulas_dir.glob("*.yml")):
        cfg = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        entries: dict = cfg.get("formulas") or {}
        if not entries:
            continue

        # A base formula is one no other entry references as its "full" sibling.
        referenced = {
            e["full-formula-ref"] for e in entries.values() if e.get("full-formula-ref")
        }
        base_keys = [k for k in entries if k not in referenced]
        primary_key = base_keys[0] if base_keys else next(iter(entries))

        # Order variants: primary first, then its full sibling, then the rest.
        ordered: list[str] = [primary_key]
        full_ref = entries[primary_key].get("full-formula-ref")
        if full_ref and full_ref in entries:
            ordered.append(full_ref)
        ordered += [k for k in entries if k not in ordered]

        multi = len(ordered) > 1
        variants: list[Variant] = []
        for key in ordered:
            entry = entries[key]
            formula_path = formula_dir / f"{key}.rb"
            if not formula_path.exists():
                continue
            python_version = entry.get("python-version")
            version = read_formula_version(formula_path)
            label, note = derive_variant_copy(entry, is_full=key in referenced)
            variants.append(
                Variant(
                    name=key,
                    formula_type=entry.get("type", ""),
                    version=version,
                    tags=derive_tags(entry, python_version),
                    install_cmd=f"brew install {key}",
                    label=label if multi else None,
                    note=note if multi else None,
                ),
            )

        if not variants:
            continue

        products.append(
            Product(
                name=primary_key,
                description=cfg.get("description", ""),
                version=variants[0].version,
                variants=variants,
            ),
        )

    return products


def derive_variant_copy(entry: dict, *, is_full: bool) -> tuple[str, str]:
    """Derive the label and short note shown for one install variant.

    Args:
        entry: A single formula entry from a product config.
        is_full: Whether this entry is another formula's "full" sibling.

    Returns:
        A ``(label, note)`` pair for the variant header.
    """
    if entry.get("type") == "binary":
        return "Standalone binary", "no python"
    if is_full or (entry.get("homebrew-deps")):
        deps = entry.get("homebrew-deps") or []
        return "Full toolkit", f"{len(deps)} tools" if deps else "all tools"
    return "PyPI install", "python library"


def render_install(cmd: str) -> str:
    """Render an install command row with a copy button.

    Args:
        cmd: The ``brew install`` command to display and copy.

    Returns:
        HTML for the install row.
    """
    safe = html.escape(cmd)
    return (
        '<div class="install"><code><span class="p">$</span> '
        f"{safe}</code>"
        f'<button class="copy" data-copy="{safe}">copy</button></div>'
    )


def render_tags(tags: list[str]) -> str:
    """Render a row of derived tags.

    Args:
        tags: Display tags for a single-variant product.

    Returns:
        HTML for the tags row.
    """
    spans = "".join(f'<span class="tag">{html.escape(t)}</span>' for t in tags)
    return f'<div class="tags">{spans}</div>'


def render_product(product: Product) -> str:
    """Render one product card, grouping install variants under the tool.

    Args:
        product: The product and its ordered install variants.

    Returns:
        HTML for the product card.
    """
    head = (
        '<article class="card">'
        '<div class="card__top">'
        f'<span class="card__name">{html.escape(product.name)}</span>'
        f'<span class="ver">{html.escape(product.version)}</span>'
        "</div>"
        f'<p class="card__desc">{html.escape(product.description)}</p>'
    )

    if len(product.variants) == 1:
        v = product.variants[0]
        body = render_tags(v.tags) + render_install(v.install_cmd)
    else:
        rows = []
        for v in product.variants:
            note = f'<span class="tag">{html.escape(v.note or "")}</span>'
            rows.append(
                '<div class="variant"><div class="variant__h">'
                f'<span class="variant__name">{html.escape(v.label or v.name)}'
                f"</span>{note}</div>"
                f"{render_install(v.install_cmd)}</div>",
            )
        body = f'<div class="variants">{"".join(rows)}</div>'

    return head + body + "</article>"


def render_page(template: str, products: list[Product]) -> str:
    """Substitute the generated catalogue into the template.

    Args:
        template: The page template containing ``{{PRODUCT_CARDS}}``.
        products: Products to render into the catalogue.

    Returns:
        The fully rendered page.

    Raises:
        ValueError: If any ``{{PLACEHOLDER}}`` remains unfilled.
    """
    cards = "\n".join(render_product(p) for p in products)
    rendered = template.replace("{{PRODUCT_CARDS}}", cards)

    leftover = sorted(set(PLACEHOLDER_PATTERN.findall(rendered)))
    if leftover:
        msg = f"Unreplaced template placeholders: {', '.join(leftover)}"
        raise ValueError(msg)
    return rendered


def main() -> None:
    """CLI entry point."""
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Build the tap landing page")
    parser.add_argument("--formulas-dir", default=str(repo_root / "formulas"))
    parser.add_argument("--formula-dir", default=str(repo_root / "Formula"))
    parser.add_argument(
        "--template",
        default=str(Path(__file__).parent / "templates" / "pages.html.template"),
    )
    parser.add_argument("--output", "-o", default="-", help="Output file or '-'")
    args = parser.parse_args()

    products = build_products(Path(args.formulas_dir), Path(args.formula_dir))
    if not products:
        print("No products found", file=sys.stderr)
        sys.exit(1)

    template = Path(args.template).read_text(encoding="utf-8")
    try:
        page = render_page(template, products)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    if args.output == "-":
        sys.stdout.write(page)
    else:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page, encoding="utf-8")
        print(f"Wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
