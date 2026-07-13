# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class Lintro < Formula
  desc "Unified CLI for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.79.1"
  license "MIT"

  # Track the latest GitHub release via the releases API rather than scanning all
  # tags, so the stray single-component "v1" tag is ignored. url :stable is
  # required by FormulaAudit/LivecheckUrlSymbol; github_latest derives the repo
  # from it, and the semver regex is a defensive filter on the release tag.
  livecheck do
    url :stable
    strategy :github_latest
    regex(/^v?(\d+\.\d+\.\d+)$/i)
  end

  on_macos do
    on_arm do
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v#{version}/lintro-macos-arm64"
      sha256 "e0034ef7a4027031f114f72a75857aac8766ceeeee1a5a7a3017726bfdf82496"
    end
    on_intel do
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v#{version}/lintro-macos-x86_64"
      sha256 "a40afbf5ca332d675e21084b7c71df19e3d7fe6365691e40522f2f16a8717fbe"
    end
  end

  # Shares the "lintro" binary with the PyPI-based full formula.
  conflicts_with "lintro-full", because: "both provide the lintro binary"

  def install
    if Hardware::CPU.arm?
      bin.install "lintro-macos-arm64" => "lintro"
    else
      bin.install "lintro-macos-x86_64" => "lintro"
    end
  end

  def caveats
    <<~EOS
      lintro is a lightweight standalone binary (no Python required).

      Install tools with:
        lintro doctor
        lintro install --profile recommended

      For all tools bundled via Homebrew dependencies:
        brew install lgtm-hq/tap/lintro-full
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lintro --version")
    assert_match "Usage:", shell_output("#{bin}/lintro --help")
    # `lintro doctor` exits non-zero when optional tools are missing (expected
    # inside the sandboxed test environment), so accept exit status 1.
    assert_match "Lintro Doctor", shell_output("#{bin}/lintro doctor", 1)
  end
end
