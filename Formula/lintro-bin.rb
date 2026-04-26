# typed: false
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class LintroBin < Formula
  desc "Unified CLI for code quality (binary)"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.61.0"
  license "MIT"

  RELEASE_BASE = "https://github.com/lgtm-hq/py-lintro/releases"

  on_macos do
    on_arm do
      url "#{RELEASE_BASE}/download/v#{version}/lintro-macos-arm64"
      sha256 "5a725daa39fdd1901a01863f7a962b02bc453f99a9e1cc0f516d3a4bca0b474d"
    end
    on_intel do
      url "#{RELEASE_BASE}/download/v#{version}/lintro-macos-x86_64"
      sha256 "86737c4b062ac4b124e59c60f024b5498b2888713f0c0deca45d8813a317d307"
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
    assert_match version.to_s, shell_output("#{bin}/lintro --version")
  end
end
