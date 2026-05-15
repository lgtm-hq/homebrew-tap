# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro
# CLI tools (ruff, black, mypy, bandit) are installed as Homebrew dependencies
# Python libraries are bundled as resources
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI tool for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  url "https://files.pythonhosted.org/packages/b9/87/cbb7df63b8e6a484d1f271da568eda67b0f9c73846ac4ed7b01339293990/lintro-0.62.4.tar.gz"
  sha256 "ed0cc901d428af712b988d83e50f757c8e1f53e31270c686a966366a83dccfd6"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "actionlint"
  depends_on "bandit"
  depends_on "black"
  depends_on "gitleaks"
  depends_on "hadolint"
  depends_on "libyaml"
  depends_on "markdownlint-cli2"
  depends_on "mypy"
  depends_on "oxfmt"
  depends_on "oxlint"
  depends_on "prettier"
  depends_on "python@3.13"
  depends_on "ruff"
  depends_on "rust" # provides clippy, rustfmt, and cargo for cargo-audit
  depends_on "semgrep"
  depends_on "shellcheck"
  depends_on "shfmt"
  depends_on "sqlfluff"
  depends_on "taplo"
  depends_on "yamllint"

  # Pure Python library dependencies
  resource "annotated-types" do
    url "https://files.pythonhosted.org/packages/ee/67/531ea369ba64dcff5ec9c3402f9f51bf748cec26dde048a2f973a4eea7f5/annotated_types-0.7.0.tar.gz"
    sha256 "aff07c09a53a08bc8cfccb9c85b05f1aa9a2a6f23728d790723543408344ce89"
  end

  resource "anyio" do
    url "https://files.pythonhosted.org/packages/19/14/2c5dd9f512b66549ae92767a9c7b330ae88e1932ca57876909410251fe13/anyio-4.13.0.tar.gz"
    sha256 "334b70e641fd2221c1505b3890c69882fe4a2df910cba14d97019b90b24439dc"
  end

  resource "ast-serialize" do
    url "https://files.pythonhosted.org/packages/e2/1f/50f241d4e01fe75f4bba6a209edd4047c4b26acf70992ff885fd161f79cb/ast_serialize-0.4.0.tar.gz"
    sha256 "74e4e634ab82d1466acf0be27043178570b98ebeaa3165f9240a6fad4c286471"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/25/ee/6caf7a40c36a1220410afe15a1cc64993a1f864871f698c0f93acb72842a/certifi-2026.4.22.tar.gz"
    sha256 "8d455352a37b71bf76a79caa83a3d6c25afee4a385d632127b6afb3963f1c580"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/bb/63/f9e1ea081ce35720d8b92acde70daaedace594dc93b693c869e0d5910718/click-8.3.3.tar.gz"
    sha256 "398329ad4837b2ff7cbe1dd166a4c0f8900c3ca3a218de04466f38f6497f18a2"
  end

  resource "coverage" do
    url "https://files.pythonhosted.org/packages/23/7f/d0720730a397a999ffc0fd3f5bebef347338e3a47b727da66fbb228e2ff2/coverage-7.14.0.tar.gz"
    sha256 "057a6af2f160a85384cde4ab36f0d2777bae1057bae255f95413cdd382aa5c74"
  end

  resource "coverage-badge" do
    url "https://files.pythonhosted.org/packages/be/8f/e92b0a010c76b0da82709838b3f3ae9aec638d0c44dbfb1186a5751f5d2e/coverage_badge-1.1.2.tar.gz"
    sha256 "fe7ed58a3b72dad85a553b64a99e963dea3847dcd0b8ddd2b38a00333618642c"
  end

  resource "defusedxml" do
    url "https://files.pythonhosted.org/packages/0f/d5/c66da9b79e5bdb124974bfe172b4daf3c984ebd9c2a06e2b8a4dc7331c72/defusedxml-0.7.1.tar.gz"
    sha256 "1bb3032db185915b62d7c6209c5a8792be6a32ab2fedacc84e01b52c51aa3e69"
  end

  resource "docstring-parser-fork" do
    url "https://files.pythonhosted.org/packages/66/bf/27f9cab2f0cd1d17a4420572088bbc19f36d726fbcf165edf226a8926dbc/docstring_parser_fork-0.0.14.tar.gz"
    sha256 "a2743a63d8d36c09650594f7b4ab5b2758fee8629dcf794d1b221b23179baa5c"
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
    url "https://files.pythonhosted.org/packages/82/77/7b3966d0b9d1d31a36ddf1746926a11dface89a83409bf1483f0237aa758/idna-3.15.tar.gz"
    sha256 "ca962446ea538f7092a95e057da437618e886f4d349216d2b1e294abfdb65fdc"
  end

  resource "librt" do
    url "https://files.pythonhosted.org/packages/40/08/9e7f6b5d2b5bed6ad055cdd5925f192bb403a51280f86b56554d9d0699a2/librt-0.11.0.tar.gz"
    sha256 "075dc3ef4458a278e0195cbf6ac9d38808d9b906c5a6c7f7f79c3888276a3fb1"
  end

  resource "loguru" do
    url "https://files.pythonhosted.org/packages/3a/05/a1dae3dffd1116099471c643b8924f5aa6524411dc6c63fdae648c4f1aca/loguru-0.7.3.tar.gz"
    sha256 "19480589e77d47b8d85b2c827ad95d49bf31b0dcde16593892eb51dd18706eb6"
  end

  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/06/ff/7841249c247aa650a76b9ee4bbaeae59370dc8bfd2f6c01f3630c35eb134/markdown_it_py-4.2.0.tar.gz"
    sha256 "04a21681d6fbb623de53f6f364d352309d4094dd4194040a10fd51833e418d49"
  end

  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end

  resource "mypy-extensions" do
    url "https://files.pythonhosted.org/packages/a2/6e/371856a3fb9d31ca8dac321cda606860fa4548858c0cc45d9d1d4ca2628b/mypy_extensions-1.1.0.tar.gz"
    sha256 "52e68efc3284861e772bbcd66823fde5ae21fd2fdb51c62a211403730b916558"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/d7/f1/e7a6dd94a8d4a5626c03e4e99c87f241ba9e350cd9e6d75123f992427270/packaging-26.2.tar.gz"
    sha256 "ff452ff5a3e828ce110190feff1178bb1f2ea2281fa2075aadb987c2fb221661"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/5a/82/42f767fc1c1143d6fd36efb827202a2d997a375e160a71eb2888a925aac1/pathspec-1.1.1.tar.gz"
    sha256 "17db5ecd524104a120e173814c90367a96a98d07c45b2e10c2f3919fff91bf5a"
  end

  resource "pip" do
    url "https://files.pythonhosted.org/packages/b6/48/cb9b7a682f6fe01a4221e1728941dd4ac3cd9090a17db3779d6ff490b602/pip-26.1.1.tar.gz"
    sha256 "d36762751d156a4ee895de8af39aa0abeeeb577f93a2eca6ab62467bbf0f8a78"
  end

  resource "platformdirs" do
    url "https://files.pythonhosted.org/packages/9f/4a/0883b8e3802965322523f0b200ecf33d31f10991d0401162f4b23c698b42/platformdirs-4.9.6.tar.gz"
    sha256 "3bfa75b0ad0db84096ae777218481852c0ebc6c727b3168c1b9e0118e458cf0a"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/18/a5/b60d21ac674192f8ab0ba4e9fd860690f9b4a6e51ca5df118733b487d8d6/pydantic-2.13.4.tar.gz"
    sha256 "c40756b57adaa8b1efeeced5c196f3f3b7c435f90e84ea7f443901bec8099ef6"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/c3/b2/bc9c9196916376152d655522fdcebac55e66de6603a76a02bca1b6414f6c/pygments-2.20.0.tar.gz"
    sha256 "6757cd03768053ff99f3039c1a36d6c0aa0b263438fcab17520b30a303a82b5f"
  end

  resource "pytokens" do
    url "https://files.pythonhosted.org/packages/b6/34/b4e015b99031667a7b960f888889c5bd34ef585c85e1cb56a594b92836ac/pytokens-0.4.1.tar.gz"
    sha256 "292052fe80923aae2260c073f822ceba21f3872ced9a68bb7953b348e561179a"
  end

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/c0/8f/0722ca900cc807c13a6a0c696dacf35430f72e0ec571c4275d2371fca3e9/rich-15.0.0.tar.gz"
    sha256 "edd07a4824c6b40189fb7ac9bc4c52536e9780fbbfbddf6f1e2502c31b068c36"
  end

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/4f/db/cfac1baf10650ab4d1c111714410d2fbb77ac5a616db26775db562c8fab2/setuptools-82.0.1.tar.gz"
    sha256 "7d872682c5d01cfde07da7bccc7b65469d3dca203318515ada1de5eda35efbf9"
  end

  resource "stevedore" do
    url "https://files.pythonhosted.org/packages/a2/6d/90764092216fa560f6587f83bb70113a8ba510ba436c6476a2b47359057c/stevedore-5.7.0.tar.gz"
    sha256 "31dd6fe6b3cbe921e21dcefabc9a5f1cf848cf538a1f27543721b8ca09948aa3"
  end

  resource "tabulate" do
    url "https://files.pythonhosted.org/packages/46/58/8c37dea7bbf769b20d58e7ace7e5edfe65b849442b00ffcdd56be88697c6/tabulate-0.10.0.tar.gz"
    sha256 "e2cfde8f79420f6deeffdeda9aaec3b6bc5abce947655d17ac662b126e48a60d"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/72/94/1a15dd82efb362ac84269196e94cf00f187f7ed21c242792a923cdb1c61f/typing_extensions-4.15.0.tar.gz"
    sha256 "0cea48d173cc12fa28ecabc3b837ea3cf6f38c6d1136f85cbaaf598984861466"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/55/e3/70399cb7dd41c10ac53367ae42139cf4b1ca5f36bb3dc6c9d33acdb43655/typing_inspection-0.4.2.tar.gz"
    sha256 "ba561c48a67c5958007083d386c3295464928b01faa735ab8547c5692e87f464"
  end
  # pydoclint - use wheel for consistency
  resource "pydoclint" do
    url "https://files.pythonhosted.org/packages/87/6f/cc2b231dc78d8c3aaa674a676db190b8f8071c50134af8f8cf39b9b8e8df/pydoclint-0.8.3-py3-none-any.whl"
    sha256 "5fc9b82d0d515afce0908cb70e8ff695a68b19042785c248c4f227ad66b4a164"
  end

  # pydantic_core requires Rust to build - use platform-specific wheels
  resource "pydantic_core" do
    on_arm do
      url "https://files.pythonhosted.org/packages/c1/81/4fa520eaffa8bd7d1525e644cd6d39e7d60b1592bc5b516693c7340b50f1/pydantic_core-2.46.4-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "c94f0688e7b8d0a67abf40e57a7eaaecd17cc9586706a31b76c031f63df052b4"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/51/a2/5d30b469c5267a17b39dec53208222f76a8d351dfac4af661888c5aee77d/pydantic_core-2.46.4-cp313-cp313-macosx_10_12_x86_64.whl"
      sha256 "5d5902252db0d3cedf8d4a1bc68f70eeb430f7e4c7104c8c476753519b423008"
    end
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")

    # Install other resources first (this sets up pip in the venv)
    other_resources = resources.reject { |r| r.name == "pydantic_core" }
    venv.pip_install other_resources

    # Install pydantic_core wheel (requires special handling due to Rust build)
    resource("pydantic_core").stage do
      wheel = Pathname.pwd.children.find { |f| f.extname == ".whl" }
      odie "pydantic_core wheel not found in staged resource" if wheel.nil?
      system libexec/"bin/python", "-m", "pip",
             "install", "--no-deps", "--ignore-installed", wheel.to_s
    end

    # Install lintro itself
    venv.pip_install_and_link buildpath
  end

  def caveats
    <<~EOS
      Lintro is now installed (#{deps.count} Homebrew formulae included).

      Python quality:   ruff, black, mypy, bandit, pydoclint (bundled)
      YAML / TOML:      yamllint, taplo
      Shell:            shellcheck, shfmt
      Markdown:         markdownlint-cli2
      JS / TS:          oxlint, oxfmt, prettier
      Dockerfiles:      hadolint
      GitHub Actions:   actionlint
      Security:         gitleaks, semgrep
      Rust:             clippy, rustfmt (via rust)
      SQL:              sqlfluff

      Not installed automatically (install if needed):
        cargo install cargo-audit cargo-deny   # Rust dependency auditing
        npm install -g astro svelte-check vue-tsc  # Framework type-checkers

      Run 'lintro doctor' to check tool status and get install hints.

      Get started:
        lintro check .        # Lint your project
        lintro format .       # Auto-fix issues
        lintro doctor         # Check which tools are available
    EOS
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/lintro --version")
  end
end
