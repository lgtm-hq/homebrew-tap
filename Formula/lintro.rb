# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro
# CLI tools (ruff, black, mypy, bandit) are installed as Homebrew dependencies
# Python libraries are bundled as resources
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI tool for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  url "https://files.pythonhosted.org/packages/aa/77/28bafa96288ada28a9d50d3fbbd961049622928ac845475be331fe1e2538/lintro-0.52.14.tar.gz"
  sha256 "b0811f26b084a41b081ec14e8b42e6cc70aa3372446ed43d5a7e0d26624c6ba4"
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
    url "https://files.pythonhosted.org/packages/96/f0/5eb65b2bb0d09ac6776f2eb54adee6abe8228ea05b20a5ad0e4945de8aac/anyio-4.12.1.tar.gz"
    sha256 "41cfcc3a4c85d3f05c932da7c26d0201ac36f72abd4435ba90d0464a3ffed703"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/af/2d/7bf41579a8986e348fa033a31cdd0e4121114f6bce2457e8876010b092dd/certifi-2026.2.25.tar.gz"
    sha256 "e887ab5cee78ea814d3472169153c2d12cd43b14bd03329a39a9c6e2e80bfba7"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/3d/fa/656b739db8587d7b5dfa22e22ed02566950fbfbcdc20311993483657a5c0/click-8.3.1.tar.gz"
    sha256 "12ff4785d337a1bb490bb7e9c2b1ee5da3112e94a8622f26a6c77f5d2fc6842a"
  end

  resource "coverage" do
    url "https://files.pythonhosted.org/packages/9d/e0/70553e3000e345daff267cec284ce4cbf3fc141b6da229ac52775b5428f1/coverage-7.13.5.tar.gz"
    sha256 "c81f6515c4c40141f83f502b07bbfa5c240ba25bbe73da7b33f1e5b6120ff179"
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
    url "https://files.pythonhosted.org/packages/6f/6d/0703ccc57f3a7233505399edb88de3cbd678da106337b9fcde432b65ed60/idna-3.11.tar.gz"
    sha256 "795dafcc9c04ed0c1fb032c2aa73654d8e8c5023a7df64a53f39190ada629902"
  end

  resource "librt" do
    url "https://files.pythonhosted.org/packages/56/9c/b4b0c54d84da4a94b37bd44151e46d5e583c9534c7e02250b961b1b6d8a8/librt-0.8.1.tar.gz"
    sha256 "be46a14693955b3bd96014ccbdb8339ee8c9346fbe11c1b78901b55125f14c73"
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

  resource "mypy-extensions" do
    url "https://files.pythonhosted.org/packages/a2/6e/371856a3fb9d31ca8dac321cda606860fa4548858c0cc45d9d1d4ca2628b/mypy_extensions-1.1.0.tar.gz"
    sha256 "52e68efc3284861e772bbcd66823fde5ae21fd2fdb51c62a211403730b916558"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/65/ee/299d360cdc32edc7d2cf530f3accf79c4fca01e96ffc950d8a52213bd8e4/packaging-26.0.tar.gz"
    sha256 "00243ae351a257117b6a241061796684b084ed1c516a08c48a3f7e147a9d80b4"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/fa/36/e27608899f9b8d4dff0617b2d9ab17ca5608956ca44461ac14ac48b44015/pathspec-1.0.4.tar.gz"
    sha256 "0210e2ae8a21a9137c0d470578cb0e595af87edaa6ebf12ff176f14a02e0e645"
  end

  resource "pip" do
    url "https://files.pythonhosted.org/packages/fe/6e/74a3f0179a4a73a53d66ce57fdb4de0080a8baa1de0063de206d6167acc2/pip-25.3.tar.gz"
    sha256 "8d0538dbbd7babbd207f261ed969c65de439f6bc9e5dbd3b3b9a77f25d95f343"
  end

  resource "platformdirs" do
    url "https://files.pythonhosted.org/packages/19/56/8d4c30c8a1d07013911a8fdbd8f89440ef9f08d07a1b50ab8ca8be5a20f9/platformdirs-4.9.4.tar.gz"
    sha256 "1ec356301b7dc906d83f371c8f487070e99d3ccf9e501686456394622a01a934"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/69/44/36f1a6e523abc58ae5f928898e4aca2e0ea509b5aa6f6f392a5d882be928/pydantic-2.12.5.tar.gz"
    sha256 "4d351024c75c0f085a9febbb665ce8c0c6ec5d30e903bdb6394b7ede26aebb49"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/b0/77/a5b8c569bf593b0140bde72ea885a803b82086995367bf2037de0159d924/pygments-2.19.2.tar.gz"
    sha256 "636cb2477cec7f8952536970bc533bc43743542f70392ae026374600add5b887"
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
    url "https://files.pythonhosted.org/packages/b3/c6/f3b320c27991c46f43ee9d856302c70dc2d0fb2dba4842ff739d5f46b393/rich-14.3.3.tar.gz"
    sha256 "b8daa0b9e4eef54dd8cf7c86c03713f53241884e814f4e2f5fb342fe520f639b"
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
      url "https://files.pythonhosted.org/packages/94/02/abfa0e0bda67faa65fef1c84971c7e45928e108fe24333c81f3bfe35d5f5/pydantic_core-2.41.5-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "112e305c3314f40c93998e567879e887a3160bb8689ef3d2c04b6cc62c33ac34"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/87/06/8806241ff1f70d9939f9af039c6c35f2360cf16e93c2ca76f184e76b1564/pydantic_core-2.41.5-cp313-cp313-macosx_10_12_x86_64.whl"
      sha256 "941103c9be18ac8daf7b7adca8228f8ed6bb7a1849020f643b3a14d15b1924d9"
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
      Lintro is now installed!

      Included tools (installed via Homebrew):
        - ruff - Python linter and formatter
        - black - Python code formatter
        - mypy - Python type checker
        - bandit - Python security linter
        - clippy - Rust linter (via rust)
        - rustfmt - Rust formatter (via rust)
        - hadolint - Dockerfile linter
        - actionlint - GitHub Actions workflow linter
        - gitleaks - Secret detection in git repos
        - markdownlint-cli2 - Markdown linter
        - oxlint - JavaScript/TypeScript linter
        - oxfmt - JavaScript/TypeScript formatter
        - prettier - Code formatter
        - yamllint - YAML linter
        - semgrep - Security scanner
        - shellcheck - Shell script analyzer
        - shfmt - Shell script formatter
        - sqlfluff - SQL linter and formatter
        - taplo - TOML linter and formatter

      Bundled tools:
        - pydoclint - Python docstring linter

      Optional (install manually via cargo):
        - cargo-audit - Rust dependency vulnerability scanner
          Install with: cargo install cargo-audit

      Get started:
        lintro check          # Check files for issues
        lintro format         # Auto-fix issues
        lintro list-tools     # View available tools

      Documentation: https://github.com/lgtm-hq/py-lintro/tree/main/docs
    EOS
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/lintro --version")
  end
end
