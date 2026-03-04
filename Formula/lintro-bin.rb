# typed: false
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class LintroBin < Formula
  desc "Unified CLI for code quality (binary)"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.52.8"
  license "MIT"

  RELEASE_BASE = "https://github.com/lgtm-hq/py-lintro/releases"

  on_macos do
    on_arm do
      url "\#{RELEASE_BASE}/download/v\#{version}/lintro-macos-arm64"
      sha256 "df9eba1ade913fc742140577d8d268176f4b578731ac113e5b95f9446708cfb3"
    end
    on_intel do
      url "\#{RELEASE_BASE}/download/v\#{version}/lintro-macos-x86_64"
      sha256 "f9a9644c5a184ab974a9cebff62866e96b4ac8bd80f9d1955fe064b54d122aea"
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
      lintro-bin is a standalone binary that doesn't require Python.

      The external tools (ruff, black, mypy, etc.) must be installed
      separately:
        brew install ruff black mypy

      For the Python version with bundled tools:
        brew install lgtm-hq/tap/lintro
    EOS
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/lintro --version")
  end
end
