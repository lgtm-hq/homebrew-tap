# Contributing to homebrew-tap

Thank you for your interest in contributing to the Lintro Homebrew tap!

## How to Contribute

### Reporting Issues

- **Formula Issues**: If you encounter problems installing or using lintro via
  Homebrew, please
  [open an issue](https://github.com/lgtm-hq/homebrew-tap/issues/new)
- **Lintro Tool Issues**: For issues with lintro itself, please report to the
  [main repository](https://github.com/lgtm-hq/py-lintro/issues)

### Formula Updates

This formula is **automatically updated** when new versions of lintro are
released to PyPI. Manual updates are generally not needed.

If you notice the formula is out of date:

1. Check if a PR is already open for the update
2. If not, feel free to open an issue

### Making Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Test the formula locally:

   ```bash
   brew install --build-from-source ./Formula/lintro.rb
   brew test lintro
   ```

5. Commit your changes with a clear message
6. Push to your fork and open a Pull Request

### Testing Locally

Before submitting changes, test the formula:

```bash
# Install from local formula
brew install --build-from-source ./Formula/lintro.rb

# Run formula tests
brew test lintro

# Audit the formula
brew audit --strict --online lintro
```

## Code of Conduct

This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this code.

## Questions?

Feel free to [open an issue](https://github.com/lgtm-hq/homebrew-tap/issues/new)
if you have questions about contributing.
