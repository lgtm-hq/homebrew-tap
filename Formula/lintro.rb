# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class Lintro < Formula
  desc "Unified CLI for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.64.5"
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
      sha256 "d4f20eb9489a538355d0844d5f5485dbd6de3e9365f05a094a553f0932a7d135"
    end
    on_intel do
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v#{version}/lintro-macos-x86_64"
      sha256 "a5c0032cde090c490b41f754c357e54f34a95dcda26794ceb81660b1f5185b27"
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
