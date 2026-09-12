# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  version "0.157.0"
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
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v#{version}/lintro-macos-arm64"
      sha256 "bff3572f1be6424b21a46fabfe7014b79a0f1d833c5fa5ba419f4652e5d9c9b5"
    end
    on_intel do
      # No x86_64 release binary is published (lgtm-hq/py-lintro#2579), so
      # Intel Macs install the same version from the PyPI sdist into a
      # Homebrew Python virtualenv.
      url "https://files.pythonhosted.org/packages/4e/53/523ab3e707153b62f47303b30d34b46f2449c2e9a023ad8de2cb4737610e/lintro-0.157.0.tar.gz"
      sha256 "182304b6ea5c6b47d580b0eb9c87cd077691f1bfafe509e70d6a11d6395898d6"

      depends_on "python@3.13"
    end
  end

  # Shares the "lintro" binary with the PyPI-based full formula.
  conflicts_with "lintro-full", because: "both provide the lintro binary"

  def install
    if Hardware::CPU.arm?
      bin.install "lintro-macos-arm64" => "lintro"
    else
      # pip resolves the dependency tree from PyPI at install time; the
      # sdist itself is checksum-pinned above. Linting tools are not bundled
      # (`lintro install` fetches them), matching the binary's footprint.
      virtualenv_create(libexec, "python3.13")
      system "python3.13", "-m", "pip",
             "--python=#{libexec}/bin/python", "install",
             "#{buildpath}[mcp]"
      bin.install_symlink libexec/"bin/lintro"
    end
  end

  def caveats
    <<~EOS
      lintro is a lightweight install: a standalone binary on Apple silicon
      (no Python required) and a PyPI virtualenv on Intel Macs.

      Install tools with:
        lintro doctor
        lintro install --profile recommended

      For all tools bundled via Homebrew dependencies:
        brew install lgtm-hq/tap/lintro-full
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lintro --version")
    # Help output renders emoji; brew test's ASCII locale crashes the
    # binary with UnicodeEncodeError, so force UTF-8 inline (an ENV
    # assignment does not reach the subprocess).
    utf8 = "LC_ALL=en_US.UTF-8"
    assert_match "Usage:", shell_output("#{utf8} #{bin}/lintro --help")
    # `lintro doctor` reports tool status and may exit non-zero when optional
    # tools are missing, so assert on its output rather than the exit status.
    doctor_cmd = "#{utf8} #{bin}/lintro doctor 2>&1"
    assert_match "Lintro Doctor", pipe_output(doctor_cmd)
  end
end
