# Homebrew Tap for Lintro

This repository contains the Homebrew formula for [lintro](https://github.com/lgtm-hq/py-lintro), a unified CLI tool for code formatting, linting, and quality assurance.

## Installation

To install lintro via Homebrew:

```bash
brew tap lgtm-hq/tap
brew install lintro
```

## Upgrading

To upgrade to the latest version:

```bash
brew update
brew upgrade lintro
```

## What's Included

Lintro includes the following tools:
- **ruff** - Python linter and formatter
- **hadolint** - Dockerfile linter
- **actionlint** - GitHub Actions workflow linter
- **prettier** - Code formatter
- **bandit** - Python security linter
- **black** - Python code formatter
- **darglint** - Python docstring linter
- **yamllint** - YAML linter

## Usage

After installation, you can use lintro:

```bash
lintro check          # Check files for issues
lintro format         # Auto-fix issues
lintro list-tools     # View available tools
lintro --version      # Check version
```

## Documentation

For more information, visit the [lintro documentation](https://github.com/lgtm-hq/py-lintro/tree/main/docs).

## Formula Maintenance

This formula is automatically updated when new versions are released to PyPI. The update process is handled by GitHub Actions workflows in the [py-lintro repository](https://github.com/lgtm-hq/py-lintro).

