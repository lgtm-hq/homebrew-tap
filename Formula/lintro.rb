# typed: false
# frozen_string_literal: true

# Homebrew formula for lintro - auto-generated on release
# Manual edits will be overwritten on next release
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI tool for code formatting, linting, and quality assurance"
  homepage "https://github.com/TurboCoder13/py-lintro"
  url "https://files.pythonhosted.org/packages/22/2a/baa18041b8df3d39019168e26ad196c9696ecce30d958658b2a32f18af72/lintro-0.23.0.tar.gz"
  sha256 "3b48555d49bc2a073a9207d7201fa19b7a0651ffd101aaa36578c838589c324a"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  depends_on "actionlint"
  depends_on "hadolint"
  depends_on "prettier"
  depends_on "python@3.13"
  depends_on "ruff"



  def install
    virtualenv_install_with_resources
  end

  def caveats
    <<~EOS
      Lintro is now installed!

      Included tools:
        - ruff - Python linter and formatter
        - hadolint - Dockerfile linter
        - actionlint - GitHub Actions workflow linter
        - prettier - Code formatter
        - bandit - Python security linter
        - black - Python code formatter
        - darglint - Python docstring linter
        - yamllint - YAML linter

      Get started:
        lintro check          # Check files for issues
        lintro format         # Auto-fix issues
        lintro list-tools     # View available tools

      Documentation: https://github.com/TurboCoder13/py-lintro/tree/main/docs
    EOS
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/lintro --version")
  end
end
