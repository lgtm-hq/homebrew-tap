<p align="center">
  <img src="https://brew.sh/assets/img/homebrew-256x256.png" width="100" height="100" alt="Homebrew">
</p>

<h1 align="center">LGTM Homebrew Tap</h1>

<p align="center">
  <strong>Official Homebrew tap for LGTM tools and utilities</strong>
</p>

<p align="center">
  Install and manage LGTM developer tools on macOS with a single command.
</p>

<p align="center">
  <a href="#-installation">Installation</a> •
  <a href="#-available-formulae">Formulae</a> •
  <a href="#-upgrading">Upgrading</a> •
  <a href="#-contributing">Contributing</a>
</p>

---

## 🚀 Installation

Add the tap to your Homebrew:

```bash
brew tap lgtm-hq/tap
```

Then install any available formula:

```bash
brew install <formula-name>
```

---

## 📦 Available Formulae

<table>
  <tr>
    <td width="50">🔧</td>
    <td><strong><a href="https://github.com/lgtm-hq/py-lintro">lintro</a></strong></td>
    <td>Lightweight standalone binary (no Python required)</td>
    <td><code>brew install lintro</code></td>
  </tr>
  <tr>
    <td width="50">📦</td>
    <td><strong><a href="https://github.com/lgtm-hq/py-lintro">lintro-full</a></strong></td>
    <td>PyPI install with all linting tools bundled via Homebrew dependencies</td>
    <td><code>brew install lintro-full</code></td>
  </tr>
</table>

---

## ⬆️ Upgrading

Update Homebrew and upgrade all formulae:

```bash
brew update && brew upgrade
```

Or upgrade a specific formula:

```bash
brew upgrade <formula-name>
```

---

## 📋 Requirements

| Requirement | Version |
| ----------- | ------- |
| macOS       | 10.15+  |
| Homebrew    | Latest  |

---

## 🔄 Formula Maintenance

Formulae are updated tap-side when caller repos send a `repository_dispatch`
event. The tap generates formulas, opens a PR, validates them, and auto-merges
after CI passes.

### Dispatch contract (caller repos)

```yaml
notify-homebrew-tap:
  runs-on: ubuntu-latest
  steps:
    - uses: peter-evans/repository-dispatch@v3
      with:
        token: ${{ secrets.HOMEBREW_TAP_DISPATCH_TOKEN }}
        repository: lgtm-hq/homebrew-tap
        event-type: update-formula
        client-payload: >-
          {
            "formula": "winnow",
            "version": "v0.0.1",
            "pypi-package": "winnow-media"
          }
```

For binary products (e.g. lintro), include SHA256s from release assets:

```json
{
  "formula": "lintro",
  "version": "v0.64.4",
  "pypi-package": "lintro",
  "binary-assets": {
    "arm64-sha": "<sha256>",
    "x86-sha": "<sha256>"
  }
}
```

| Field | Required | Description |
| ----- | -------- | ----------- |
| `formula` | yes | Product config name (`formulas/<formula>.yml`) |
| `version` | yes | Release version (with or without `v` prefix) |
| `pypi-package` | no | Override PyPI package name from config |
| `binary-assets` | for binary formulas | `arm64-sha` and `x86-sha` from release assets |

### Product config schema (`formulas/*.yml`)

Each product declares metadata and one or more formula entries:

```yaml
package: winnow-media
source-repo: lgtm-hq/winnow
homepage: https://github.com/lgtm-hq/winnow
license: MIT
description: "Short product description"

formulas:
  winnow:
    type: pypi
    python-version: "3.13"
    test-command: "winnow --version"
```

Formula entry fields:

| Field | Applies to | Description |
| ----- | ---------- | ----------- |
| `type` | all | `pypi` or `binary` |
| `python-version` | pypi | Homebrew Python dependency (e.g. `3.13`) |
| `test-command` | all | Command used in the formula `test` block |
| `generate-resources` | pypi | Run importlib.metadata resource generation |
| `homebrew-deps` | pypi | CLI tools installed via `depends_on` |
| `wheel-only-packages` | pypi | Packages installed from wheels (not sdist) |
| `binary-url-pattern` | binary | Release URL with `{version}` and `{arch}` |
| `binary-names` | binary | Asset filenames per architecture |
| `install-name` | binary | Binary name installed to `$PREFIX/bin` |
| `class-name` | optional | Override Homebrew class name |
| `description` | optional | Override product-level description |
| `caveats` | optional | Multi-line caveats block |

### Adding a new product

1. Add `formulas/<product>.yml` following the schema above.
2. Add a `repository_dispatch` step to the caller repo's release workflow (see
   [lgtm-ci#342](https://github.com/lgtm-hq/lgtm-ci/issues/342) for the thin
   `trigger-homebrew-update` action once available).
3. Store `HOMEBREW_TAP_DISPATCH_TOKEN` (fine-grained PAT with dispatch access)
   in the caller repo secrets.
4. Merge the first generated PR — validation and auto-merge run automatically.

### Tooling dependencies

Tap scripts reuse [lgtm-ci](https://github.com/lgtm-hq/lgtm-ci) for PyPI
registry helpers (`wait_for_package`, `get_pypi_download_url`, `get_pypi_sha256`).
CI workflows sparse-checkout lgtm-ci at the same ref as `reusable-quality`
(`6a80f4a55e4080272b2d93b30cc292d618f5dd5a`, v0.45.0).

For local development and tests:

```bash
bash scripts/ci/ensure-lgtm-ci-tooling.sh
bash scripts/ci/run-tests.sh
```

Advanced PyPI resource generation (`lintro-full`) still uses tap-local Python
helpers; simple PyPI formulas and PyPI polling delegate to lgtm-ci.

See [issue #44](https://github.com/lgtm-hq/homebrew-tap/issues/44) for the full
design and migration plan.

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.

---

<p align="center">
  <a href="https://github.com/lgtm-hq">LGTM</a> •
  <a href="https://github.com/lgtm-hq/homebrew-tap/issues">Issues</a> •
  <a href="CONTRIBUTING.md">Contributing</a>
</p>
