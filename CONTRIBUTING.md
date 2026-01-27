# Contributing to LGTM Homebrew Tap

Thank you for your interest in contributing to the LGTM Homebrew tap!

## How to Contribute

### Reporting Issues

- **Formula Issues**: If you encounter problems installing or using a formula,
  please [open an issue](https://github.com/lgtm-hq/homebrew-tap/issues/new)
- **Tool-Specific Issues**: For issues with the tools themselves (not the
  Homebrew formula), please report to the respective tool's repository

### Formula Updates

Formulae are **automatically updated** when new versions are released. Manual
updates are generally not needed.

If you notice a formula is out of date:

1. Check if a PR is already open for the update
2. If not, feel free to open an issue

### Adding a New Formula

To propose a new formula:

1. Fork the repository
2. Create a new formula in `Formula/`
3. Follow [Homebrew's formula cookbook](https://docs.brew.sh/Formula-Cookbook)
4. Test locally (see below)
5. Open a Pull Request

### Making Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Test the formula locally:

   ```bash
   brew install --build-from-source ./Formula/<formula>.rb
   brew test <formula>
   ```

5. Commit your changes with a clear message
6. Push to your fork and open a Pull Request

### Testing Locally

Before submitting changes, test the formula:

```bash
# Install from local formula
brew install --build-from-source ./Formula/<formula>.rb

# Run formula tests
brew test <formula>

# Audit the formula
brew audit --strict --online <formula>
```

## Code of Conduct

This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this code.

## Questions?

Feel free to [open an issue](https://github.com/lgtm-hq/homebrew-tap/issues/new)
if you have questions about contributing.
