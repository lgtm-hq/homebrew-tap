# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow binary distribution
# Auto-generated - do not edit manually
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Organize, deduplicate, and keep the best from your media library"
  homepage "https://github.com/lgtm-hq/winnow"
  version "0.0.1"
  license "MIT"

  # Track the latest GitHub release via the releases API rather than scanning all
  # tags, so the stray single-component "v1" tag is ignored. The stable url is
  # architecture-specific (release asset on arm, PyPI sdist on intel), so the
  # homepage anchors github_latest instead; the semver regex is a defensive
  # filter on the release tag.
  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+\.\d+\.\d+)$/i)
  end

  on_macos do
    on_arm do
      url "https://github.com/lgtm-hq/winnow/releases/download/v#{version}/winnow-macos-arm64"
      sha256 "{{ARM64_SHA}}"
    end
    on_intel do
      # No x86_64 release binary is published (lgtm-hq/py-lintro#2579), so
      # Intel Macs install the same version from the PyPI sdist into a
      # Homebrew Python virtualenv. Every Python dependency is a url+sha256
      # pinned resource below; nothing is resolved from PyPI at install time.
      url "https://files.pythonhosted.org/packages/ab/cd/winnow_media-0.0.1.tar.gz"
      sha256 "846f7278e1ed929233c9de42a039eb42eb3a633f19517c7b65ed25f4a4ebe343"

      depends_on "python@3.13"

      # Pure Python library dependencies
      resource "click" do
        url "https://files.pythonhosted.org/packages/96/d3/f04c7bfcf5c1862a2a5b845c6b2b360488cf47af55dfa79c98f6a6bf98b5/click-8.1.7.tar.gz"
        sha256 "ca9853ad459e787e2192211578cc907e7594e294c7ccc834310722b41b9ca6de"
      end
    end
  end

  def install
    if Hardware::CPU.arm?
      bin.install "winnow-macos-arm64" => "winnow"
    else
      venv = virtualenv_create(libexec, "python3.13")

      venv.pip_install resources

      # Install the package itself. Homebrew's pip_install runs pip with
      # --no-deps; the dependency closure (winnow-media) is the
      # pinned resource set above.
      venv.pip_install_and_link buildpath
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/winnow --version")
  end
end
