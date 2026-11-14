# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro-full
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class LintroFull < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI for code quality (all tools included)"
  homepage "https://github.com/lgtm-hq/py-lintro"
  url "https://files.pythonhosted.org/packages/a7/9f/008f3473ffbc46ba9d3f9f8dd8dc71831373756cd76d718fb9333c83bf4c/lintro-0.180.29.tar.gz"
  sha256 "216d10ad5c0bc4cc0743431eb9a4b3b9bebd6077c0d13b736745d8bc5020bb3b"
  license "MIT"
  head "https://github.com/lgtm-hq/py-lintro.git", branch: "main"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "actionlint"
  depends_on "bandit"
  depends_on "black"
  depends_on "commitlint"
  depends_on "dotenv-linter"
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
  depends_on "vale"
  depends_on "yamllint"

  # Shares the "lintro" binary with the lightweight binary formula.
  conflicts_with "lintro", because: "both provide the lintro binary"

  # Pure Python library dependencies
  resource "annotated-types" do
    url "https://files.pythonhosted.org/packages/5f/56/a8120250d128bed162cd73c76d45f6ef9991f3e068f62a8ee060afa3104a/annotated_types-0.8.0.tar.gz"
    sha256 "13b2beaad985e05e2d6407ee4c4f35590b11f8d693a258a561055cac8f64cab7"
  end

  resource "anyio" do
    url "https://files.pythonhosted.org/packages/a1/98/7e457a3b014976887a050561955c0b76e1e7e2d6e27b78ecef2ef80518f2/anyio-4.16.0.tar.gz"
    sha256 "59bb03251907983d1603d27c3087ddb1e93299ea2163adcdba37899a4fb12ffb"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/fd/11/b524cbd9bbdaca58608e4cf4053fd463417549e1959fa8d3aa18319f9555/certifi-2026.10.23.tar.gz"
    sha256 "a9895e6e2758b371e0545e321a3a8fd1fcfd9829ada8824a936dfb16aaaf36cd"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/45/37/edbf1b0707709013c0cf2e8317e03d97ed29bf4cac709fe328904ae92a38/click-8.5.1.tar.gz"
    sha256 "9bbfada76703fd1d784b83eea012e3e8c6a001a876543ef104fa56aaaeb072b4"
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

  resource "identify" do
    url "https://files.pythonhosted.org/packages/53/35/d70c0006c7cee65999ea94a6273e60b2094f600a3d8b71b04318253fc643/identify-2.6.20.tar.gz"
    sha256 "ad729860a923858d26917c2f4fb0a1d83d27a75b1e090c06440c573f048f3285"
  end

  resource "idna" do
    url "https://files.pythonhosted.org/packages/f5/08/8eea9d4b8302028f3abb2c0813953f7aec26d33b7a8960ed760e65ff29fa/idna-3.20.tar.gz"
    sha256 "a7db850025b95ded1eae8a46181a1a6c56c92c96f0e2b005d9ff8dc0210cab44"
  end

  resource "loguru" do
    url "https://files.pythonhosted.org/packages/61/ce/b5bb93d4d9fc7a067f69140b3bb3782f6ad6360bc76e99b6e3d386cb1320/loguru-0.8.0.tar.gz"
    sha256 "fb3e4623288e37700a0577f6e0ce776cc1860b5d95c657d67f07a2476b304867"
  end

  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/16/fc/cee2c45553c9a9bf77d8b0c391560c556d7ed756b1f0bb35eb5d48db09ea/markdown_it_py-4.3.0.tar.gz"
    sha256 "91a58fa5b72c71a40cf7177250fd767480d7a2bb3ac426ccfb76fb90305fdaaa"
  end

  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz"
    sha256 "94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/5a/82/42f767fc1c1143d6fd36efb827202a2d997a375e160a71eb2888a925aac1/pathspec-1.1.1.tar.gz"
    sha256 "17db5ecd524104a120e173814c90367a96a98d07c45b2e10c2f3919fff91bf5a"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/b4/fc/1203d011145c98ddce3cd2f505bb54375ef8d43223053df6bfcf3c746f46/pydantic-2.14.3.tar.gz"
    sha256 "1054f237f4d4733e5a30e1e2333bd33a2004ab9ab1510bd053a9a31bb48e232d"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz"
    sha256 "610ca751c9bc2492b38eb9a38a7fbc93edbbb2d7182edaf34e66ae493dee5c8c"
  end

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/c0/8f/0722ca900cc807c13a6a0c696dacf35430f72e0ec571c4275d2371fca3e9/rich-15.0.0.tar.gz"
    sha256 "edd07a4824c6b40189fb7ac9bc4c52536e9780fbbfbddf6f1e2502c31b068c36"
  end

  resource "tabulate" do
    url "https://files.pythonhosted.org/packages/46/58/8c37dea7bbf769b20d58e7ace7e5edfe65b849442b00ffcdd56be88697c6/tabulate-0.10.0.tar.gz"
    sha256 "e2cfde8f79420f6deeffdeda9aaec3b6bc5abce947655d17ac662b126e48a60d"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
    sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/ff/50/0195198eb1d75bab716bb0a813abea4cc394bfa17a92a189f021a34859af/typing_inspection-0.4.5.tar.gz"
    sha256 "7f16c411e7930dc79596d42ab44672a3fe5f60eb34b781a1647e7872363120c7"
  end

  resource "watchdog" do
    url "https://files.pythonhosted.org/packages/e2/55/087e45c2a3ed8223bc9f30d6b65f051de35513cfc30c989c2b1a14bf862e/watchdog-7.1.0.tar.gz"
    sha256 "d3861e255416f49a1384474cb2efa097de165fb330d4c5432ce6708b509ed922"
  end

  # pydantic-core requires Rust to build - use platform-specific wheels
  resource "pydantic-core" do
    on_arm do
      url "https://files.pythonhosted.org/packages/90/a9/fc89a632331882c4cb91b949003418e6f5085ddcf2c9b875d499682bca91/pydantic_core-2.50.4-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "1239daaf063e62213ca1f34d96663900bd7510c42a786e843fd328af70e46445"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/1b/21/39f8d97e7ea8e3083606ee9bb1d7f3ec70ded780bb6a872aad76c7eb08b2/pydantic_core-2.50.4-cp313-cp313-macosx_10_12_x86_64.whl"
      sha256 "0f87ae9db5ba8d8de40dcb93982cf8dd544e6552a80d3345af51941cc2146b80"
    end
  end
  def install
    venv = virtualenv_create(libexec, "python3.13")

    # Install other resources first (this sets up pip in the venv)
    wheel_only = %w[pydantic-core]
    other_resources = resources.reject { |r| wheel_only.include?(r.name) }
    venv.pip_install other_resources

    # Install prebuilt platform wheels out-of-band: building these from
    # source needs heavy native toolchains (Rust, C/Fortran).
    wheel_only.each do |name|
      resource(name).stage do
        wheel = Pathname.pwd.children.find { |f| f.extname == ".whl" }
        odie "#{name} wheel not found in staged resource" if wheel.nil?
        system libexec/"bin/python", "-m", "pip",
               "install", "--no-deps", "--ignore-installed", wheel.to_s
      end
    end

    # Install the package itself
    venv.pip_install_and_link buildpath
  end

  def caveats
    <<~EOS
      Lintro is now installed (#{deps.count} Homebrew formulae included).

      Python quality:   ruff, black, mypy, bandit, pydoclint (bundled)
      YAML / TOML:      yamllint, taplo
      Shell:            shellcheck, shfmt
      Dotenv:           dotenv-linter
      Markdown:         markdownlint-cli2
      Prose / docs:     vale
      JS / TS:          oxlint, oxfmt, prettier
      Dockerfiles:      hadolint
      GitHub Actions:   actionlint
      Git commits:      commitlint
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
