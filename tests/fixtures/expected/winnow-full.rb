# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Organize, deduplicate, and keep the best from your media library"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/ab/cd/winnow_media-0.0.1.tar.gz"
  sha256 "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "python@3.13"

  # Pure Python library dependencies
  resource "click" do
    url "https://files.pythonhosted.org/packages/96/d3/f04c7bfcf5c1862a2a5b845c6b2b360488cf47af55dfa79c98f6a6bf98b5/click-8.1.7.tar.gz"
    sha256 "ca9853ad459e787e2192211578cc907e7594e294c7ccc834310722b41b9ca6de"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")

    venv.pip_install resources

    # Install the package itself
    venv.pip_install_and_link buildpath
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/winnow --version")
  end
end
