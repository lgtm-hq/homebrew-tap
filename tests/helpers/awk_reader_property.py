#!/usr/bin/env python3
"""Generate product-config layouts to check config-formula-keys.awk.

Writes plain and mutated config layouts to WORK_DIR and reads each with the
real ``read_formula_config.py --list-formulas``. Prints one tab-separated
line per case: file name, 1 for a plain layout (the awk reader must read it
exactly) or 0, and the sorted formula keys, or ``ERROR`` when the reader
rejects the file. tests/bats/unit/ci/test_detect_formula_changes.bats runs
the awk reader on every case under every installed awk and requires the
same set, or a fall back to every formula; never a smaller or different set.

Usage:
    awk_reader_property.py READER_PY WORK_DIR
"""

from __future__ import annotations

import contextlib
import io
import runpy
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar

import yaml

T = TypeVar("T")


class Lcg:
    """Small deterministic generator, so the cases are the same on every run.

    Args:
        seed: Starting state.
    """

    def __init__(self, seed: int) -> None:
        self.state = seed

    def below(self, limit: int) -> int:
        """Return the next number in [0, limit).

        Args:
            limit: Exclusive upper bound, positive.

        Returns:
            The number.
        """
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % (2**64)
        return (self.state >> 33) % limit

    def randint(self, low: int, high: int) -> int:
        """Return a number in [low, high].

        Args:
            low: Inclusive lower bound.
            high: Inclusive upper bound.

        Returns:
            The number.
        """
        return low + self.below(high - low + 1)

    def chance(self, percent: int) -> bool:
        """Return True with the given probability.

        Args:
            percent: Probability in percent.

        Returns:
            Whether the event happens.
        """
        return self.below(100) < percent

    def choice(self, items: Sequence[T]) -> T:
        """Pick one item.

        Args:
            items: Non-empty sequence.

        Returns:
            The item.
        """
        return items[self.below(len(items))]

    def sample(self, items: Sequence[T], count: int) -> list[T]:
        """Pick distinct items.

        Args:
            items: Sequence to pick from.
            count: Number of items, at most len(items).

        Returns:
            The items, in pick order.
        """
        pool = list(items)
        return [pool.pop(self.below(len(pool))) for _ in range(count)]


SEED = 661
PLAIN_CASES = 150
MUTATED_CASES = 450
KEY_POOL = ("alpha", "beta", "gamma-full", "delta.v2", "eps_1", "zeta")

PREAMBLE_ENTRIES = (
    "package: alpha\n",
    "description: 'Quoted: text # not a comment'\n",
    'title: "double \\" quoted"\n',
    "homepage: https://example.com/a#b\n",
    "notes: |\n  formulas:\n  beta: x\n  - item\n",
    "summary: >-\n  folded text\n  formulas: here\n",
    "provenance:\n  repo: a/b\n  require-attestation: true\n",
    "items:\n  - a\n  - 'b'\n  - {c: 1}\n",
    "# top-level comment\n",
    "empty:\n",
)

TRAILING_ENTRIES = (
    "",
    "other: 1\n",
    "# trailing comment\nlast:\n  nested: x\n",
)


@dataclass(frozen=True)
class Case:
    """One generated config file."""

    name: str
    text: str
    plain: bool


def nested_body(rng: Lcg, indent: int, step: int) -> str:
    """Build the lines nested under one formula key.

    Args:
        rng: Random source.
        indent: Indentation of the formula key.
        step: Indentation step of the file.

    Returns:
        The nested lines, possibly empty.
    """
    pad = " " * (indent + step)
    deeper = " " * (indent + 2 * step)
    parts = [
        f"{pad}type: pypi\n",
        f"{pad}test-command: 'tool --version'\n",
        f'{pad}python-version: "3.13"\n',
        f"{pad}extras:\n{deeper}- mcp\n{deeper}- 'cli'\n",
        f"{pad}extras-inline: [mcp, cli]\n",
        f"{pad}meta: {{a: 1, b: [2, 3]}}\n",
        (
            f'{pad}test-extra: |\n{deeper}beta:\n{deeper}"open quote\n'
            f"{deeper}- not: a key\n\n{deeper}  more\n"
        ),
        f"{pad}comment: >-\n{deeper}folded: text\n{deeper}zeta: no\n",
        f"{pad}# nested comment\n",
        "# column-zero comment\n",
        "\n",
        f"{pad}url: https://example.com/x?y=1#frag\n",
        f"{pad}nested:\n{deeper}inner: value # comment: here\n",
    ]
    count = rng.randint(0, 4)
    return "".join(rng.choice(parts) for _ in range(count))


def plain_config(rng: Lcg) -> str:
    """Build a config in the layout the awk reader accepts.

    Args:
        rng: Random source.

    Returns:
        YAML text.
    """
    step = rng.choice((2, 4))
    text = rng.choice(("", "---\n", "# header\n---\n", "\n"))
    for entry in rng.sample(PREAMBLE_ENTRIES, rng.randint(0, 4)):
        text += entry
    text += rng.choice(("formulas:\n", "formulas:  # the formulas\n"))
    keys = rng.sample(KEY_POOL, rng.randint(1, 4))
    for key in keys:
        if rng.chance(30):
            text += f"{' ' * step}{key}: {{}}\n"
            continue
        if rng.chance(20):
            text += f"{' ' * step}# about {key}\n"
        body = nested_body(rng, step, step)
        if not body.strip():
            body = f"{' ' * (2 * step)}type: binary\n"
        text += f"{' ' * step}{key}:\n{body}"
    text += rng.choice(TRAILING_ENTRIES)
    return text


def line_mutations(line: str) -> list[str]:
    """List replacements for one line under ``formulas:``.

    Args:
        line: The line, with its newline.

    Returns:
        Replacement texts, each a layout the awk reader refuses or that YAML
        reads differently.
    """
    rest = line.lstrip(" ")
    pad = line[: len(line) - len(rest)]
    key, value = rest.rstrip("\n").split(":", 1)
    return [
        f"{pad}? {key}\n{pad}: {{}}\n",
        f"{pad}{key}\n{pad}  : {{}}\n",
        f"\t{rest}",
        f'{pad}"{key}":{value}\n',
        f"{pad}true: {{}}\n",
        f"{pad}010: {{}}\n",
        f" {line}",
        f"{pad}{key}-x:\n{pad} odd: 1\n{line[1:] if len(pad) > 1 else line}",
        f'{pad}{key}-q:\n{pad}  desc: "open\n{pad}zeta: closed"\n{line}',
        f"{pad}{key}-f:\n{pad}  extras: [a,\n{pad}zeta: b]\n{line}",
        f"{pad}{key} :\n",
        f"{pad}<<: {{omega: {{}}}}\n",
        f"{pad}&anchor {rest}",
        f"{pad}- {rest}",
        f"{pad}{key}: 'open\n{pad}zeta: x'\n",
    ]


FILE_MUTATIONS = (
    lambda text: text + "---\nformulas:\n  omega: {}\n",
    lambda text: text + "...\n",
    lambda text: text + "formulas:\n  omega: {}\n",
    lambda text: text.replace("\n", "\r\n"),
    lambda text: "%YAML 1.1\n---\n" + text,
)


def mutate(rng: Lcg, text: str) -> str:
    """Apply one layout change to a line under ``formulas:`` or to the file.

    Args:
        rng: Random source.
        text: A plain config.

    Returns:
        The mutated YAML text.
    """
    lines = text.splitlines(keepends=True)
    start = next(i for i, x in enumerate(lines) if x.startswith("formulas:"))
    targets = [
        index
        for index, line in enumerate(lines)
        if index > start
        and line.startswith(" ")
        and line.lstrip(" ")[:1].isalpha()
        and ":" in line
    ]
    choices = line_mutations(lines[targets[0]]) if targets else []
    pick = rng.below(len(choices) + len(FILE_MUTATIONS))
    if pick >= len(choices):
        return FILE_MUTATIONS[pick - len(choices)](text)
    target = rng.choice(targets)
    lines[target] = rng.choice(line_mutations(lines[target]))
    return "".join(lines)


def python_keys(reader: Path, config: Path) -> list[str] | None:
    """Run read_formula_config.py --list-formulas in this process.

    Args:
        reader: Path to read_formula_config.py.
        config: Config file to read.

    Returns:
        The printed keys, or None when the reader fails.
    """
    saved = sys.argv
    sys.argv = [str(reader), str(config), "--list-formulas"]
    buffer = io.StringIO()
    try:
        with (
            contextlib.redirect_stdout(buffer),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            runpy.run_path(str(reader), run_name="__main__")
    except SystemExit as stop:
        if stop.code not in (None, 0):
            return None
    except (yaml.YAMLError, AttributeError, TypeError, UnicodeDecodeError):
        return None
    finally:
        sys.argv = saved
    return buffer.getvalue().splitlines()


def generate_cases() -> list[Case]:
    """Generate the plain and mutated layouts.

    Returns:
        The cases, deterministic for SEED.
    """
    rng = Lcg(SEED)
    cases = [
        Case(f"plain-{n}", plain_config(rng), plain=True) for n in range(PLAIN_CASES)
    ]
    cases += [
        Case(f"mutated-{n}", mutate(rng, plain_config(rng)), plain=False)
        for n in range(MUTATED_CASES)
    ]
    return cases


def main() -> int:
    """Write every generated case and print the reader's answer for it.

    Returns:
        Process exit status.
    """
    reader, work_dir = (Path(arg) for arg in sys.argv[1:3])
    for case in generate_cases():
        config = work_dir / f"{case.name}.yml"
        config.write_bytes(case.text.encode())
        keys = python_keys(reader, config)
        expected = "ERROR" if keys is None else " ".join(sorted(set(keys)))
        print(f"{config.name}\t{int(case.plain)}\t{expected}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
