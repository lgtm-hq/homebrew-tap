# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro-full
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class LintroFull < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI for code quality (all tools included)"
  homepage "https://github.com/lgtm-hq/py-lintro"
  url "https://files.pythonhosted.org/packages/d0/bf/19019cb1ad91aa1c04100a6608b2fce38598a93549008eb0bab157ac67dc/lintro-0.181.6.tar.gz"
  sha256 "bd204bb0e10fe5f701f69570aa7e8ee0246fbe5f9b96ee8772c04af1bc4041e7"
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

  resource "astroid" do
    url "https://files.pythonhosted.org/packages/2d/87/5732fa68bf100a095cfcbd108f919220d995db99e1a7502b8119a869fd62/astroid-4.3.4.tar.gz"
    sha256 "d515a105722b72098bbe82d430d65e635f742b6cbac3bdfaf8b7c188b87c5e39"
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

  resource "dill" do
    url "https://files.pythonhosted.org/packages/81/e1/56027a71e31b02ddc53c7d65b01e68edf64dea2932122fe7746a516f75d5/dill-0.4.1.tar.gz"
    sha256 "423092df4182177d4d8ba8290c8a5b640c66ab35ec7da59ccfa00f6fa3eea5fa"
  end

  resource "docstring-parser-fork" do
    url "https://files.pythonhosted.org/packages/04/ce/48b17c6c24d0af112f73721a90fac245450e548b82b53169260720f60d07/docstring_parser_fork-0.0.16.tar.gz"
    sha256 "9ecf861ceab8b87d1297a71001c15a1956ad02e87434ee6473643a5988094f7c"
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

  resource "import-linter" do
    url "https://files.pythonhosted.org/packages/f0/70/ac97afe41a04239a60c9d92fbe593294bf6501309d728af4a400e569d786/import_linter-2.16.tar.gz"
    sha256 "c5bd0d38bdef46c7251120266b3bf72662bc8cd989a8fe461499936e12e8c6fa"
  end

  resource "loguru" do
    url "https://files.pythonhosted.org/packages/61/ce/b5bb93d4d9fc7a067f69140b3bb3782f6ad6360bc76e99b6e3d386cb1320/loguru-0.8.0.tar.gz"
    sha256 "fb3e4623288e37700a0577f6e0ce776cc1860b5d95c657d67f07a2476b304867"
  end

  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/16/fc/cee2c45553c9a9bf77d8b0c391560c556d7ed756b1f0bb35eb5d48db09ea/markdown_it_py-4.3.0.tar.gz"
    sha256 "91a58fa5b72c71a40cf7177250fd767480d7a2bb3ac426ccfb76fb90305fdaaa"
  end

  resource "mccabe" do
    url "https://files.pythonhosted.org/packages/e7/ff/0ffefdcac38932a54d2b5eed4e0ba8a408f215002cd178ad1df0f2806ff8/mccabe-0.7.0.tar.gz"
    sha256 "348e0240c33b60bbdf4e523192ef919f28cb2c3d7d5c7794f74009290f236325"
  end

  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end

  resource "mypy-extensions" do
    url "https://files.pythonhosted.org/packages/d0/6f/43edf3be2748d0e40974a5ee046a8bb4c9961a4bdd3e7d5c6dcbf32d1af6/mypy_extensions-1.2.0.tar.gz"
    sha256 "c6e275a07f1c2fc096b62940452d0eaa3f3af7de45d704787866240a7c6d5a51"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz"
    sha256 "94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/5a/82/42f767fc1c1143d6fd36efb827202a2d997a375e160a71eb2888a925aac1/pathspec-1.1.1.tar.gz"
    sha256 "17db5ecd524104a120e173814c90367a96a98d07c45b2e10c2f3919fff91bf5a"
  end

  resource "platformdirs" do
    url "https://files.pythonhosted.org/packages/d7/9a/8475be631fb33ca1466915e70fd594c42a4e84b512db650eaa14f90fe75d/platformdirs-4.14.5.tar.gz"
    sha256 "32e9921db7385aa8169bee4fe9501923e5715ba9fb7ea3b9c69b0d8e0639f7a1"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/b4/fc/1203d011145c98ddce3cd2f505bb54375ef8d43223053df6bfcf3c746f46/pydantic-2.14.3.tar.gz"
    sha256 "1054f237f4d4733e5a30e1e2333bd33a2004ab9ab1510bd053a9a31bb48e232d"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz"
    sha256 "610ca751c9bc2492b38eb9a38a7fbc93edbbb2d7182edaf34e66ae493dee5c8c"
  end

  resource "pylint" do
    url "https://files.pythonhosted.org/packages/8f/d7/bfea980ba1ea5666c7f774627f3a7159b98a21426a081dd2f05db8eb93b3/pylint-4.1.4.tar.gz"
    sha256 "4c9176dc6c9f1b98b742195f01899b290369d5a27b4b41d1014c17f2f96b26f1"
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

  resource "tomlkit" do
    url "https://files.pythonhosted.org/packages/08/72/fc01563df95c189a9f65850096bdc205bc2fe37da6c740cd64afaf18d07e/tomlkit-0.15.2.tar.gz"
    sha256 "83e32755ba1d20d9340bd069ee97e9f6232ba2346b63ffcba425de01f7e327a6"
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

  # pydoclint - use wheel for consistency
  resource "pydoclint" do
    url "https://files.pythonhosted.org/packages/6e/45/9aea4898fcfbb3ed973eb23f6b83c677bb8bcecb59e9681fae6da82bb3be/pydoclint-0.12.0-py3-none-any.whl"
    sha256 "28f5763a865cb19b54883dfe68b05b01d2c2fc2e8d59dcf424cc345bc976a689"
  end
  # isort (pylint) - its sdist's build requirements include mypy's compiled toolchain; use the wheel
  resource "isort" do
    url "https://files.pythonhosted.org/packages/8b/c9/0849e74b868ef10312eecfc24278710e97dd14bc49c1df629d7df142d318/isort-9.0.2-py3-none-any.whl"
    sha256 "6c29deeb39698a8717823b7f75b2ac58c5e8ab8dcf6cf31205a72a6617fb454e"
  end
  # grimp (import-linter) builds a Rust extension - use platform-specific wheels
  resource "grimp" do
    on_arm do
      url "https://files.pythonhosted.org/packages/4b/f4/7d59b62774acdd71b147f21fd434bb22f105d2fce44db79f35d23fda0920/grimp-3.20-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "7da53af57d8f8789655e513f57332ab7604cd89b6c80c6e9ad4d8caa5f7ac630"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/2f/cc/916d444d13987babaea358f179efb093e41b0c0f732c82d08108245062ba/grimp-3.20-cp313-cp313-macosx_10_12_x86_64.whl"
      sha256 "a5ad98fe1421c1007508a6bce595630385920340fbc2b43588c80ad73cefcb92"
    end
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
    wheel_only = %w[grimp pydantic-core]
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
    venv.pip_install "#{buildpath}[full]"

    # lintro runs the tools pinned above as plain commands. They are
    # in this formula's own environment, so the launcher adds it to PATH,
    # after the user's own entries.
    launcher_path = "${PATH}:#{libexec}/bin"
    (bin/"lintro").write_env_script libexec/"bin/lintro", PATH: launcher_path
  end

  def caveats
    <<~EOS
      Lintro is now installed (#{deps.count} Homebrew formulae included).

      Python quality:   ruff, black, mypy, bandit
                        pydoclint, pylint, import-linter (bundled, run by lintro)
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
    # The bundled tools are pinned in this formula's own environment,
    # which is not on PATH; the launcher must make lintro find them.
    (testpath/"sample.py").write "import os\n"
    bundled = "--tools pylint,pydoclint,import_linter"
    bundled_cmd = "#{utf8} #{bin}/lintro chk #{bundled} #{testpath}/sample.py 2>&1"
    bundled_out = pipe_output(bundled_cmd)
    assert_match "EXECUTION SUMMARY", bundled_out
    %w[pylint pydoclint import-linter].each { |tool| assert_match tool, bundled_out }
    refute_match "not found in PATH", bundled_out
    refute_match "UNAVAIL", bundled_out
  end
end
