# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro
# CLI tools (ruff, black, mypy, bandit) are installed as Homebrew dependencies
# Python libraries are bundled as resources
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI tool for code formatting, linting, and quality assurance"
  homepage "https://github.com/TurboCoder13/py-lintro"
  url "https://files.pythonhosted.org/packages/11/ac/68fb00e57ea4e69e927c8e9c495591cbc127bd0748e9f68267918e248478/lintro-0.24.0.tar.gz"
  sha256 "223f64a4c7fc1279c94871bb49c984878a56971528ad6af06a128e84c782c1b4"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "actionlint"
  depends_on "bandit"
  depends_on "black"
  depends_on "hadolint"
  depends_on "mypy"
  depends_on "prettier"
  depends_on "python@3.13"
  depends_on "ruff"
  depends_on "yamllint"

  # Pure Python library dependencies
  resource "annotated-types" do
    url "https://files.pythonhosted.org/packages/ee/67/531ea369ba64dcff5ec9c3402f9f51bf748cec26dde048a2f973a4eea7f5/annotated_types-0.7.0.tar.gz"
    sha256 "aff07c09a53a08bc8cfccb9c85b05f1aa9a2a6f23728d790723543408344ce89"
  end

  resource "anyio" do
    url "https://files.pythonhosted.org/packages/16/ce/8a777047513153587e5434fd752e89334ac33e379aa3497db860eeb60377/anyio-4.12.0.tar.gz"
    sha256 "73c693b567b0c55130c104d0b43a9baf3aa6a31fc6110116509f27bf75e21ec0"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/a2/8c/58f469717fa48465e4a50c014a0400602d3c437d7c0c468e17ada824da3a/certifi-2025.11.12.tar.gz"
    sha256 "d8ab5478f2ecd78af242878415affce761ca6bc54a22a27e026d7c25357c3316"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/b9/2e/0090cbf739cee7d23781ad4b89a9894a41538e4fcf4c31dcdd705b78eb8b/click-8.1.8.tar.gz"
    sha256 "ed53c9d8990d83c2a27deae68e4ee337473f6330c040a31d4225c9574d16096a"
  end

  resource "coverage" do
    url "https://files.pythonhosted.org/packages/b6/45/2c665ca77ec32ad67e25c77daf1cee28ee4558f3bc571cdbaf88a00b9f23/coverage-7.13.0.tar.gz"
    sha256 "a394aa27f2d7ff9bc04cf703817773a59ad6dfbd577032e690f961d2460ee936"
  end

  resource "coverage-badge" do
    url "https://files.pythonhosted.org/packages/be/8f/e92b0a010c76b0da82709838b3f3ae9aec638d0c44dbfb1186a5751f5d2e/coverage_badge-1.1.2.tar.gz"
    sha256 "fe7ed58a3b72dad85a553b64a99e963dea3847dcd0b8ddd2b38a00333618642c"
  end

  # darglint uses wheel (py3-none-any) since it requires poetry to build from source
  resource "darglint" do
    url "https://files.pythonhosted.org/packages/69/28/85d1e0396d64422c5218d68e5cdcc53153aa8a2c83c7dbc3ee1502adf3a1/darglint-1.8.1-py3-none-any.whl"
    sha256 "5ae11c259c17b0701618a20c3da343a3eb98b3bc4b5a83d31cdd94f5ebdced8d"
  end

  resource "defusedxml" do
    url "https://files.pythonhosted.org/packages/0f/d5/c66da9b79e5bdb124974bfe172b4daf3c984ebd9c2a06e2b8a4dc7331c72/defusedxml-0.7.1.tar.gz"
    sha256 "1bb3032db185915b62d7c6209c5a8792be6a32ab2fedacc84e01b52c51aa3e69"
  end

  resource "h11" do
    url "https://files.pythonhosted.org/packages/01/ee/02a2c011bdab74c6fb3c75474d40b3052059d95df7e73351460c8588d963/h11-0.16.0.tar.gz"
    sha256 "4e35b956cf45792e4caa5885e69fba00bdbc6ffafbfa020300e549b208ee5ff1"
  end

  resource "httpcore" do
    url "https://files.pythonhosted.org/packages/06/94/82699a10bca87a5556c9c59b5963f2d039dbd239f25bc2a63907a05a14cb/httpcore-1.0.9.tar.gz"
    sha256 "6e34463af53fd2ab5d807f399a9b45ea31c3dfa2276f15a2c3f00afff6e176e8"
  end

  resource "httpx" do
    url "https://files.pythonhosted.org/packages/b1/df/48c586a5fe32a0f01324ee087459e112ebb7224f646c0b5023f5e79e9956/httpx-0.28.1.tar.gz"
    sha256 "75e98c5f16b0f35b567856f597f06ff2270a374470a5c2392242528e3e3e42fc"
  end

  resource "idna" do
    url "https://files.pythonhosted.org/packages/6f/6d/0703ccc57f3a7233505399edb88de3cbd678da106337b9fcde432b65ed60/idna-3.11.tar.gz"
    sha256 "795dafcc9c04ed0c1fb032c2aa73654d8e8c5023a7df64a53f39190ada629902"
  end

  resource "loguru" do
    url "https://files.pythonhosted.org/packages/3a/05/a1dae3dffd1116099471c643b8924f5aa6524411dc6c63fdae648c4f1aca/loguru-0.7.3.tar.gz"
    sha256 "19480589e77d47b8d85b2c827ad95d49bf31b0dcde16593892eb51dd18706eb6"
  end

  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/5b/f5/4ec618ed16cc4f8fb3b701563655a69816155e79e24a17b651541804721d/markdown_it_py-4.0.0.tar.gz"
    sha256 "cb0a2b4aa34f932c007117b194e945bd74e0ec24133ceb5bac59009cda1cb9f3"
  end

  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/a1/d4/1fc4078c65507b51b96ca8f8c3ba19e6a61c8253c72794544580a7b6c24d/packaging-25.0.tar.gz"
    sha256 "d443872c98d677bf60f6a1f2f8c1cb748e8fe762d2bf9d3148b5599295b0fc4f"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/ca/bc/f35b8446f4531a7cb215605d100cd88b7ac6f44ab3fc94870c120ab3adbf/pathspec-0.12.1.tar.gz"
    sha256 "a482d51503a1ab33b1c67a6c3813a26953dbdc71c31dacaef9a838c4e29f5712"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/69/44/36f1a6e523abc58ae5f928898e4aca2e0ea509b5aa6f6f392a5d882be928/pydantic-2.12.5.tar.gz"
    sha256 "4d351024c75c0f085a9febbb665ce8c0c6ec5d30e903bdb6394b7ede26aebb49"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/b0/77/a5b8c569bf593b0140bde72ea885a803b82086995367bf2037de0159d924/pygments-2.19.2.tar.gz"
    sha256 "636cb2477cec7f8952536970bc533bc43743542f70392ae026374600add5b887"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/fb/d2/8920e102050a0de7bfabeb4c4614a49248cf8d5d7a8d01885fbb24dc767a/rich-14.2.0.tar.gz"
    sha256 "73ff50c7c0c1c77c8243079283f4edb376f0f6442433aecb8ce7e6d0b92d1fe4"
  end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  resource "sniffio" do
    url "https://files.pythonhosted.org/packages/a2/87/a6771e1546d97e7e041b6ae58d80074f81b7d5121207425c964ddf5cfdbd/sniffio-1.3.1.tar.gz"
    sha256 "f4324edc670a0f49750a81b895f35c3adb843cca46f0530f79fc1babb23789dc"
  end

  resource "tabulate" do
    url "https://files.pythonhosted.org/packages/ec/fe/802052aecb21e3797b8f7902564ab6ea0d60ff8ca23952079064155d1ae1/tabulate-0.9.0.tar.gz"
    sha256 "0095b12bf5966de529c0feb1fa08671671b3368eec77d7ef7ab114be2c068b3c"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/72/94/1a15dd82efb362ac84269196e94cf00f187f7ed21c242792a923cdb1c61f/typing_extensions-4.15.0.tar.gz"
    sha256 "0cea48d173cc12fa28ecabc3b837ea3cf6f38c6d1136f85cbaaf598984861466"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/55/e3/70399cb7dd41c10ac53367ae42139cf4b1ca5f36bb3dc6c9d33acdb43655/typing_inspection-0.4.2.tar.gz"
    sha256 "ba561c48a67c5958007083d386c3295464928b01faa735ab8547c5692e87f464"
  end

  # pydantic_core requires Rust to build - use platform-specific wheel
  resource "pydantic_core" do
    on_arm do
      url "https://files.pythonhosted.org/packages/94/02/abfa0e0bda67faa65fef1c84971c7e45928e108fe24333c81f3bfe35d5f5/pydantic_core-2.41.5-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "112e305c3314f40c93998e567879e887a3160bb8689ef3d2c04b6cc62c33ac34"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/f6/f4/7802c5abe3893aa1bf208da6cf076e3c77197e77db3c0f6af5e2e5d93e57/pydantic_core-2.41.5-cp313-cp313-macosx_10_12_x86_64.whl"
      sha256 "6a1e37470b7c89ee3a0effe4eb50ab40ad9fb6ed79fc00f5980a2e47e3bf28e6"
    end
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")

    # Install other resources first (this sets up pip in the venv)
    other_resources = resources.reject { |r| r.name == "pydantic_core" }
    venv.pip_install other_resources

    # Now install pydantic_core wheel (pip is available now)
    resource("pydantic_core").stage do
      wheel = Pathname.pwd.children.find { |f| f.extname == ".whl" }
      system "python3.13", "-m", "pip", "--python=#{libexec}/bin/python",
             "install", "--no-deps", "--ignore-installed", wheel.to_s
    end

    # Install lintro itself
    venv.pip_install_and_link buildpath
  end

  def caveats
    <<~EOS
      Lintro is now installed!

      Included tools (installed via Homebrew):
        - ruff - Python linter and formatter
        - black - Python code formatter
        - mypy - Python type checker
        - bandit - Python security linter
        - hadolint - Dockerfile linter
        - actionlint - GitHub Actions workflow linter
        - prettier - Code formatter
        - yamllint - YAML linter

      Bundled tools:
        - darglint - Python docstring linter

      Get started:
        lintro check          # Check files for issues
        lintro format         # Auto-fix issues
        lintro list-tools     # View available tools

      Documentation: https://github.com/TurboCoder13/py-lintro/tree/main/docs
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lintro --version")
  end
end
