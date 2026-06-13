# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# Auto-generated - do not edit manually
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Winnow your media library — organize, deduplicate, keep the best"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/bf/c2/6e85d776307f09acee6ed4e89a0cfa45e0a0f23aa300678aadd19704a45f/winnow_media-0.0.3.tar.gz"
  sha256 "cc7efa4394920eac8e289178d8f5b5f60ec0d354aea8d10317e86c29442b86c0"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  depends_on "python@3.13"

  def install
    venv = virtualenv_create(libexec, "python3.13")
    venv.pip_install_and_link buildpath
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/winnow --version")
  end
end
