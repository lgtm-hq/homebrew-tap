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
  <tr>
    <td width="50">🎬</td>
    <td><strong><a href="https://github.com/lgtm-hq/winnow">winnow</a></strong></td>
    <td>PyPI install with pinned dependencies (full template, like lintro-full)</td>
    <td><code>brew install winnow</code></td>
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

> **Note:** the update PR is opened by the `homebrew-tap-release-bot` GitHub App,
> not `GITHUB_TOKEN`. PRs opened with `GITHUB_TOKEN` do not trigger `pull_request`
> CI, so required checks never run and auto-merge never fires — see
> [#80](https://github.com/lgtm-hq/homebrew-tap/issues/80). Keep the App token on
> the PR-creation step.

### CI token architecture

Automated formula PRs use three credential roles. Org secrets are shared across
`lgtm-hq` repos (`HOMEBREW_TAP_APP_*`); caller repos only need the dispatch PAT.

| Credential | Where stored | Used for |
| ---------- | ------------ | -------- |
| `HOMEBREW_TAP_DISPATCH_TOKEN` | Caller repo secret (py-lintro, winnow, …) | `repository_dispatch` to trigger `update-formula.yml` |
| `HOMEBREW_TAP_APP_ID` + `HOMEBREW_TAP_APP_PRIVATE_KEY` | Org secret | Mint installation tokens for `homebrew-tap-release-bot` |
| App installation token | Generated in workflow (`create-github-app-token`) | `git push` on formula branches; `gh pr merge --auto` |
| `GITHUB_TOKEN` | Per-workflow (no secret) | `gh pr create` / `gh pr list` in `update-formula.yml` |

The `homebrew-tap-release-bot` GitHub App pushes formula branches so
`pull_request` CI runs without a maintainer clicking **Approve and run
workflows** (GitHub blocks workflows on branches pushed with `GITHUB_TOKEN` from
another workflow). PRs are still opened with `GITHUB_TOKEN`, so the PR author is
usually `github-actions[bot]`; `merge-release-bot-pr.sh` trusts that identity
along with the App.

Auto-merge uses the App installation token so merges satisfy the org
`review-required` ruleset bypass granted to `homebrew-tap-release-bot`.

`RELEASE_APP_ID` / `RELEASE_APP_PRIVATE_KEY` are a different App (`lgtm-release-bot`)
used by product-repo release workflows — not this tap pipeline.

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
description: "Organize, deduplicate, and keep the best from your media library"

formulas:
  winnow:
    type: pypi
    generate-resources: true
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
| `description` | optional | Override product-level description. Must be non-empty and must not start with the formula name ([FormulaAudit/Desc](https://docs.brew.sh/Formula-Cookbook#summary)). Generators validate before render; mid-word prefixes (e.g. `WinnowTool`) are not caught and still fail `brew audit`. |
| `caveats` | optional | Multi-line caveats block |

Generated formulas include `# typed: strict` (Sorbet) in the header for
consistent typing across PyPI and binary templates.

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
CI workflows sparse-checkout lgtm-ci at the same ref as the reusable quality
workflows (`23c79b65490a3307fb08cdefafa22db12f75b9b2`, v0.63.1). The `uses:`
refs and the `tooling-ref` / `LGTM_CI_TOOLING_REF` inputs are kept in lockstep;
bump them together.

For local development and tests:

```bash
bash scripts/ci/ensure-lgtm-ci-tooling.sh
bash scripts/ci/run-tests.sh
```

Advanced PyPI resource generation (`lintro-full`, `winnow`) uses tap-local Python
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
