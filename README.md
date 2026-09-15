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
    <td>Lightweight install: standalone binary on Apple silicon (no Python required), PyPI virtualenv on Intel</td>
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
| App installation token | Generated in workflow (`create-github-app-token`) | Signed commits via GraphQL, `gh pr create`, `gh attestation verify`, `gh api` release lookups in `update-formula.yml`; `gh pr merge --auto` in `merge-release-bot-pr.yml` |
| `GITHUB_TOKEN` | Per-workflow (no secret) | Read-only checkout and the scheduled-validation issue reports |

`update-formula.yml` runs every `gh` call, including `gh pr create`, with the
App installation token: commits are created through the GraphQL
`createCommitOnBranch` API (GitHub-signed, satisfying `required_signatures`),
and the PR is opened by `homebrew-tap-release-bot[bot]`, so `pull_request` CI
runs without a maintainer clicking **Approve and run workflows** and the
release-bot PR can auto-merge (#80, #129). `merge-release-bot-pr.sh` trusts
that App identity (and the legacy `github-actions[bot]` author).

Auto-merge uses the App installation token so merges satisfy the org
`review-required` ruleset bypass granted to `homebrew-tap-release-bot`.

`RELEASE_APP_ID` / `RELEASE_APP_PRIVATE_KEY` are a different App (`lgtm-release-bot`)
used by product-repo release workflows — not this tap pipeline.

The dispatch token only authorises *starting* an update. It is not the trust
anchor for what gets pinned: that is the provenance verification below.

### What the tap verifies before pinning

Every `update-formula` run re-derives trust from the artifacts themselves
(`scripts/ci/lib/provenance.sh`, lgtm-hq/homebrew-tap#471). A dispatch for a
release that fails any check exits before a formula is rendered, so no PR is
opened; the failure names the asset and the identity that was checked.

| Artifact | Check | Identity / source |
| -------- | ----- | ----------------- |
| arm64 release binary | sha256 equals the dispatched `arm64-sha` | dispatch payload |
| arm64 release binary | `gh attestation verify --repo <repo> --signer-workflow <binary-signer-workflow>` | `provenance.repo`, `provenance.binary-signer-workflow` |
| sdist | PyPI JSON digest == downloaded digest == GitHub Release asset digest (`releases/tags/<tag-prefix><version>` `.assets[].digest`) | `provenance.repo`, `provenance.tag-prefix` |
| sdist | PEP 740 provenance at `pypi.org/integrity/<pkg>/<ver>/<file>/provenance` names the same file and digest, published from the expected repository/workflow | `provenance.repo`, `provenance.pypi-publisher-workflow` |
| sdist | `gh attestation verify --repo <repo> --signer-workflow <sdist-signer-workflow>` | `provenance.sdist-signer-workflow` |
| Intel dependency tree | every dependency of the sdist (with `intel-pypi.extras`) is a url+sha256 `resource`; install runs pip with `--no-deps` only | generated from the sdist metadata, same code path as `lintro-full` |

`require-attestation: true` makes a failed or missing attestation fatal;
`false` (or absent) only warns, which is how a product adopts the checks
before its release pipeline signs artifacts. The digest cross-checks and the
PEP 740 check always run once `provenance.repo` is set. Products without a
`provenance:` block (winnow today) get the sha256 checks only.

For lintro the identities are py-lintro's nested reusable
`build-binaries.yml` (binaries) and lgtm-ci's
`reusable-build-python-dist.yml` (sdist/wheel), with
`publish-pypi-on-tag.yml` as the PyPI Trusted Publisher; py-lintro ships
attested artifacts and `<asset>.intoto.jsonl` bundles since
lgtm-hq/py-lintro#2562. `gh attestation verify` needs egress to
`api.github.com` and `tuf-repo-cdn.sigstore.dev`; both are in the
`update-formula.yml` harden-runner allowlist.

Formula CI (`validate-homebrew-formula.yml`) installs every formula from
source, runs `brew audit --strict --online`, `brew test` and a `--version`
smoke check; a formula that does not install fails the run. Accepted audit
findings are listed explicitly in `scripts/ci/validate-formulas.sh`.

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

For binary products (e.g. lintro), include the SHA256 of the arm64 release
asset:

```json
{
  "formula": "lintro",
  "version": "v0.64.4",
  "pypi-package": "lintro",
  "binary-assets": {
    "arm64-sha": "<sha256>"
  }
}
```

A legacy `x86-sha` key is still accepted (validated, then ignored): binary
formulas no longer ship an x86_64 asset, and Intel Macs install the same
version from the PyPI sdist (see `intel-pypi` below).

| Field | Required | Description |
| ----- | -------- | ----------- |
| `formula` | yes | Product config name (`formulas/<formula>.yml`) |
| `version` | yes | Release version (with or without `v` prefix) |
| `pypi-package` | no | Override PyPI package name from config |
| `binary-assets` | for binary formulas | `arm64-sha` from the release asset (`x86-sha` accepted and ignored) |

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
| `wheel-only-packages` | pypi | Packages installed from wheels (not sdist); the key is the PyPI lookup name, the rendered `resource` is its PEP 503 normalized form (`pydantic_core` becomes `pydantic-core`, as `brew audit --strict` requires) |
| `binary-url-pattern` | binary | Release URL with `{version}` and `{arch}` |
| `binary-names` | binary | Asset filenames per architecture (`arm64`) |
| `intel-pypi` | binary | Intel fallback: `python-version` (Homebrew Python dependency), `extras` (PyPI extras whose dependencies are pinned too, e.g. `[mcp]`), `min-resource-count`, `homebrew-deps` (a name, or `{name, build: true}` for a build-time dependency such as `rust`, rendered as `depends_on "rust" => :build`) and `wheel-only-packages` (same shape as a pypi entry). The `on_intel` branch installs `package` at the same version from the PyPI sdist into a virtualenv with every dependency pinned as a `resource`. |
| `provenance` | optional (product level, per-formula override) | `require-attestation`, `repo`, `tag-prefix`, `binary-signer-workflow`, `sdist-signer-workflow`, `pypi-publisher-workflow`; see "What the tap verifies before pinning". |
| `install-name` | binary | Binary name installed to `$PREFIX/bin` |
| `class-name` | optional | Override Homebrew class name |
| `description` | optional | Override product-level description. Must be non-empty and must not start with the formula name ([FormulaAudit/Desc](https://docs.brew.sh/Formula-Cookbook#summary)). Generators validate before render; mid-word prefixes (e.g. `WinnowTool`) are not caught and still fail `brew audit`. |
| `caveats` | optional | Multi-line caveats block |

Generated formulas include `# typed: strict` (Sorbet) in the header for
consistent typing across PyPI and binary templates. No `bottle` block is
generated: the tap builds no bottles.

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
workflows (`7c82f643fd70415c58d55c182c9d994cbd45075e`, v0.74.0). The `uses:`
refs and the `tooling-ref` / `LGTM_CI_TOOLING_REF` inputs (`ci.yml`,
`ai-review.yml`, `pr-auto-assign.yml`, `update-formula.yml`,
`deploy-pages.yml`, `scripts/ci/lib/lgtm-ci-tooling.sh`) are kept in
lockstep; bump them together.

Shared shell libraries live in `scripts/ci/lib/` (the path lgtm-ci's
`reusable-test-shell.yml` instruments with kcov), and the bats suite enforces
the coverage floor set by `coverage-threshold` in `ci.yml`.

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
