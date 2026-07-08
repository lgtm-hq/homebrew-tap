# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class Lintro < Formula
  desc "Unified CLI for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.69.3"
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
      sha256 "7daa11b7a3149ba773b1e3a8b0a4fe50fad1f9ab83328a7a1446498906ed6c32"
    end
    on_intel do
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v#{version}/lintro-macos-x86_64"
      sha256 "b47b922ab4ca33ce9f15f395e22a8d0bc8dfa40b900a08f790d379c662ad3023"
    end
  end

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
  end
end
