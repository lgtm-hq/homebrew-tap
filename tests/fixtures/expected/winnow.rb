# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# Auto-generated - do not edit manually
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Winnow your media library — organize, deduplicate, keep the best"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/ab/cd/winnow_media-0.0.1.tar.gz"
  sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  depends_on "python@3.13"

  def install
    virtualenv_create(libexec, "python3.13")
    pip_install_and_link buildpath
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/winnow --version")
  end
end
