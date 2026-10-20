# typed: strict
# frozen_string_literal: true

# Homebrew formula for lintro binary distribution
# Auto-generated - do not edit manually
class Lintro < Formula
  include Language::Python::Virtualenv

  desc "Unified CLI for code formatting, linting, and quality assurance"
  homepage "https://github.com/lgtm-hq/py-lintro"
  license "MIT"

  # The version is scanned from the architecture-specific stable url (release
  # asset on arm, PyPI sdist on intel); an explicit `version` would be
  # redundant (brew audit --strict). Track the latest GitHub release via the
  # releases API rather than scanning all tags, so the stray single-component
  # "v1" tag is ignored; the homepage anchors github_latest and the semver
  # regex is a defensive filter on the release tag.
  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+\.\d+\.\d+)$/i)
  end

  on_macos do
    on_arm do
      url "https://github.com/lgtm-hq/py-lintro/archive/refs/tags/v0.173.1.tar.gz"
      sha256 "88e8e040f95a305e583f7aafe3184331b8f8072447fc5c964e630d1ebaf5d0d0"
    end
    on_intel do
      # No x86_64 release binary is published (lgtm-hq/py-lintro#2579), so
      # Intel Macs install the same version from the PyPI sdist into a
      # Homebrew Python virtualenv. Every Python dependency is a url+sha256
      # pinned resource below; nothing is resolved from PyPI at install time.
      url "https://files.pythonhosted.org/packages/d6/b8/9e75d1bb668a99cb79c7a48b14b611274b27d8ae49dff60a90b444d9370b/lintro-0.172.0.tar.gz"
      sha256 "2b49e216e17fa5b68abcbdfb7cc27066cb78504bc78c452838a7234fb5cafb2c"

      depends_on "rust" => :build
      depends_on "libyaml"
      depends_on "python@3.13"

      # Pure Python library dependencies
      resource "annotated-types" do
        url "https://files.pythonhosted.org/packages/5f/56/a8120250d128bed162cd73c76d45f6ef9991f3e068f62a8ee060afa3104a/annotated_types-0.8.0.tar.gz"
        sha256 "13b2beaad985e05e2d6407ee4c4f35590b11f8d693a258a561055cac8f64cab7"
      end

      resource "anyio" do
        url "https://files.pythonhosted.org/packages/a9/d2/f4d173e22df740bc37b1db102b386ba719b66e95b0f0d751f556b387e6d2/anyio-4.15.1.tar.gz"
        sha256 "9f28306018cbd6d329e64a36d58256edff76dd996fe423bc957326e578b82a94"
      end

      resource "attrs" do
        url "https://files.pythonhosted.org/packages/9a/8e/82a0fe20a541c03148528be8cac2408564a6c9a0cc7e9171802bc1d26985/attrs-26.1.0.tar.gz"
        sha256 "d03ceb89cb322a8fd706d4fb91940737b6642aa36998fe130a9bc96c985eff32"
      end

      resource "certifi" do
        url "https://files.pythonhosted.org/packages/a6/bd/1436c50cc46699de0230fbaacc1d1de7bfec413176099949e9d5112e88f2/certifi-2026.10.19.tar.gz"
        sha256 "035c1e85572b141bf1c3a3eff0e33a8eb74917522f2559075ff8d2fea780a1ae"
      end

      resource "cffi" do
        url "https://files.pythonhosted.org/packages/9e/ef/008a1939e372c06329a3fce4279c02f328488f3526744906eeec3da7ad5f/cffi-2.1.1.tar.gz"
        sha256 "dd31f52ea1086513bb9df30f8fcee9b8918323ae067a3d5b78bc826a000712be"
      end

      resource "click" do
        url "https://files.pythonhosted.org/packages/c7/0e/7fa0ef50764b67090eca4114772a2abf8b6148198475e54c660b97caeee6/click-8.5.0.tar.gz"
        sha256 "ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34"
      end

      resource "cryptography" do
        url "https://files.pythonhosted.org/packages/9d/af/182eb91b0df3fe75c4d9f26fe70684569566745f6ba7e5c9c73a862c5252/cryptography-50.0.2.tar.gz"
        sha256 "7b46165bb56eb4704e2eaaf86f3c940d19154535d9b0ca7d6d590b04060e00d5"
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

      resource "httpcore2" do
        url "https://files.pythonhosted.org/packages/c2/a9/11bc39967bb9dfaab0981ab4d49f519818acbee662a7e76d06813319c838/httpcore2-2.15.1.tar.gz"
        sha256 "a94b6b3e6260e1a3f035915408d3dcd7dc8e844c2b544b642e227cf98a747af0"
      end

      resource "httpx" do
        url "https://files.pythonhosted.org/packages/b1/df/48c586a5fe32a0f01324ee087459e112ebb7224f646c0b5023f5e79e9956/httpx-0.28.1.tar.gz"
        sha256 "75e98c5f16b0f35b567856f597f06ff2270a374470a5c2392242528e3e3e42fc"
      end

      resource "httpx2" do
        url "https://files.pythonhosted.org/packages/7f/85/07978f4afd168d6b408fa75c1dc13e3010653a81e182aa1b6d89ab94d9c6/httpx2-2.15.1.tar.gz"
        sha256 "ff75485308fbe441e75b1218546e4e78d884df41e1a9741c1f79335ed8fcfef7"
      end

      resource "identify" do
        url "https://files.pythonhosted.org/packages/53/35/d70c0006c7cee65999ea94a6273e60b2094f600a3d8b71b04318253fc643/identify-2.6.20.tar.gz"
        sha256 "ad729860a923858d26917c2f4fb0a1d83d27a75b1e090c06440c573f048f3285"
      end

      resource "idna" do
        url "https://files.pythonhosted.org/packages/f5/08/8eea9d4b8302028f3abb2c0813953f7aec26d33b7a8960ed760e65ff29fa/idna-3.20.tar.gz"
        sha256 "a7db850025b95ded1eae8a46181a1a6c56c92c96f0e2b005d9ff8dc0210cab44"
      end

      resource "jsonschema" do
        url "https://files.pythonhosted.org/packages/b3/fc/e067678238fa451312d4c62bf6e6cf5ec56375422aee02f9cb5f909b3047/jsonschema-4.26.0.tar.gz"
        sha256 "0c26707e2efad8aa1bfc5b7ce170f3fccc2e4918ff85989ba9ffa9facb2be326"
      end

      resource "jsonschema-specifications" do
        url "https://files.pythonhosted.org/packages/19/74/a633ee74eb36c44aa6d1095e7cc5569bebf04342ee146178e2d36600708b/jsonschema_specifications-2025.9.1.tar.gz"
        sha256 "b540987f239e745613c7a9176f3edb72b832a4ac465cf02712288397832b5e8d"
      end

      resource "loguru" do
        url "https://files.pythonhosted.org/packages/3a/05/a1dae3dffd1116099471c643b8924f5aa6524411dc6c63fdae648c4f1aca/loguru-0.7.3.tar.gz"
        sha256 "19480589e77d47b8d85b2c827ad95d49bf31b0dcde16593892eb51dd18706eb6"
      end

      resource "markdown-it-py" do
        url "https://files.pythonhosted.org/packages/06/ff/7841249c247aa650a76b9ee4bbaeae59370dc8bfd2f6c01f3630c35eb134/markdown_it_py-4.2.0.tar.gz"
        sha256 "04a21681d6fbb623de53f6f364d352309d4094dd4194040a10fd51833e418d49"
      end

      resource "mcp" do
        url "https://files.pythonhosted.org/packages/9d/8d/e0d339616f4810e9051d4aba6887afab289ab1f81875fe908b606cdfd0e3/mcp-2.3.0.tar.gz"
        sha256 "8b147a50441cf059dc88c684e0aeed3687f0aa0f39c6cde7b90330effd2b34d8"
      end

      resource "mcp-types" do
        url "https://files.pythonhosted.org/packages/9e/2d/7c251e34207f6c51000312fc8839111ac45cfe02023f90b44e7f1051dd8e/mcp_types-2.3.0.tar.gz"
        sha256 "d1e46549edb35ee19a94940fcee6d1addd7e589ab7ea92dda83f5d84781fc362"
      end

      resource "mdurl" do
        url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
        sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
      end

      resource "opentelemetry-api" do
        url "https://files.pythonhosted.org/packages/2e/02/6e0ae9cc61bd3169d401077b507b3ebc344745171e1051ab430be012dcd9/opentelemetry_api-1.45.1.tar.gz"
        sha256 "aa38ed19bcc084ba42782a73255b3582283eced7ad6dddbd6695189e69adfb75"
      end

      resource "packaging" do
        url "https://files.pythonhosted.org/packages/7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz"
        sha256 "94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79"
      end

      resource "pathspec" do
        url "https://files.pythonhosted.org/packages/5a/82/42f767fc1c1143d6fd36efb827202a2d997a375e160a71eb2888a925aac1/pathspec-1.1.1.tar.gz"
        sha256 "17db5ecd524104a120e173814c90367a96a98d07c45b2e10c2f3919fff91bf5a"
      end

      resource "pycparser" do
        url "https://files.pythonhosted.org/packages/da/a8/c5fdbeee588bb8ada9458774f43adf1bdd30bd59157055142183e769a024/pycparser-3.11.tar.gz"
        sha256 "d875f09c3507d00e1aba0eecc6dcadc1352f30fff09dc6bff2f1c2935e97c2bc"
      end

      resource "pydantic" do
        url "https://files.pythonhosted.org/packages/7c/0b/8e10b2e693af8ec54346a14caf36221334775975a747c9ceaa3f8371d96d/pydantic-2.14.1.tar.gz"
        sha256 "94f478203dd03404682a1ada216965651dd74b1d2d5ffd62e00e0837caab5c26"
      end

      resource "pygments" do
        url "https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz"
        sha256 "610ca751c9bc2492b38eb9a38a7fbc93edbbb2d7182edaf34e66ae493dee5c8c"
      end

      resource "pyjwt" do
        url "https://files.pythonhosted.org/packages/43/ea/5194e52748b0da83d71e082d75496eaec6e58f419f5e184786ded517e6a9/pyjwt-2.15.1.tar.gz"
        sha256 "4f259e80cdfb6b3fc18a7de51fd1ef9ec79652f25019bae68975ca2468a34df8"
      end

      resource "python-multipart" do
        url "https://files.pythonhosted.org/packages/5b/42/55c32bb9b12693c092ad250a0e82edb5b31ddeda6eb772de5f308b3804ad/python_multipart-0.0.32.tar.gz"
        sha256 "be54b7f3fa167bb83e4fcd936b887b708f4e57fe75911c02aebf53efaf8d938e"
      end

      resource "pyyaml" do
        url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
        sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
      end

      resource "referencing" do
        url "https://files.pythonhosted.org/packages/22/f5/df4e9027acead3ecc63e50fe1e36aca1523e1719559c499951bb4b53188f/referencing-0.37.0.tar.gz"
        sha256 "44aefc3142c5b842538163acb373e24cce6632bd54bdb01b21ad5863489f50d8"
      end

      resource "rich" do
        url "https://files.pythonhosted.org/packages/c0/8f/0722ca900cc807c13a6a0c696dacf35430f72e0ec571c4275d2371fca3e9/rich-15.0.0.tar.gz"
        sha256 "edd07a4824c6b40189fb7ac9bc4c52536e9780fbbfbddf6f1e2502c31b068c36"
      end

      resource "rpds-py" do
        url "https://files.pythonhosted.org/packages/42/68/3bd46b8a5e01d3c2ebdf9c5e9497912e3fe0cde02bac21a7130ca866e403/rpds_py-2026.9.1.tar.gz"
        sha256 "4793ef7f78268b124b73fa933440f01d258bbae01de9fa53e9080c9ab0425a12"
      end

      resource "sse-starlette" do
        url "https://files.pythonhosted.org/packages/e4/be/0123026f719d1a7936f214a88b553bb5701e04ff2511147c1dab0c5035eb/sse_starlette-3.5.0.tar.gz"
        sha256 "75de713aa8a9441513cc283220826da079d982770965b951e9437720e8bafdb2"
      end

      resource "starlette" do
        url "https://files.pythonhosted.org/packages/ad/eb/4e197bf26b023abafc5e9043ec8710d7de0fcb032d0969045236d72aa0b1/starlette-1.9.0.tar.gz"
        sha256 "3d931de246ed870e35ce605974440816ef895e592f255d1396cfdf191d4c4318"
      end

      resource "tabulate" do
        url "https://files.pythonhosted.org/packages/46/58/8c37dea7bbf769b20d58e7ace7e5edfe65b849442b00ffcdd56be88697c6/tabulate-0.10.0.tar.gz"
        sha256 "e2cfde8f79420f6deeffdeda9aaec3b6bc5abce947655d17ac662b126e48a60d"
      end

      resource "truststore" do
        url "https://files.pythonhosted.org/packages/ee/9f/c5201d42a484c061e528825fc8e2d565f5abd50a4ced6fb7d29c4ec99b2b/truststore-0.10.5.tar.gz"
        sha256 "30d36967ccaded5cbb38d602c433f53600036c79d502f4533a49b60a03bbefcd"
      end

      resource "typing-extensions" do
        url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
        sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
      end

      resource "typing-inspection" do
        url "https://files.pythonhosted.org/packages/a3/26/b09b8010994eccc3c09092e6b34058f36a460eea2d4c3e8b910c695975a0/typing_inspection-0.4.4.tar.gz"
        sha256 "547274fa6b0a561ccf549cc9524b999a578e737d015d8709d021f9d0d13bea47"
      end

      resource "uvicorn" do
        url "https://files.pythonhosted.org/packages/da/34/30e9280707135d2cfc589dfff3cb796bd07a3aeb1a3e415ba09dd89d7bb4/uvicorn-0.54.0.tar.gz"
        sha256 "a2e33cbfaa0306f8e6b0c13e0cb89d7d7a2da3e62b90c66e18c33d9807b28620"
      end

      resource "watchdog" do
        url "https://files.pythonhosted.org/packages/db/7d/7f3d619e951c88ed75c6037b246ddcf2d322812ee8ea189be89511721d54/watchdog-6.0.0.tar.gz"
        sha256 "9ddf7c82fda3ae8e24decda1338ede66e1c99883db93711d8fb941eaa2d8c282"
      end

      # pydantic-core requires Rust to build - use platform-specific wheels
      resource "pydantic-core" do
        url "https://files.pythonhosted.org/packages/ae/57/0e237d7091d2cd44a35d243b7344227f90440166860469cd036afc23a04d/pydantic_core-2.50.1-cp313-cp313-macosx_10_12_x86_64.whl"
        sha256 "d5e062c01286d861fd6a1c4ff6e063547b3e713067f2df033c0ff97ac2ca006b"
      end
    end
  end

  # Shares the "lintro" binary with the PyPI-based full formula.
  conflicts_with "lintro-full", because: "both provide the lintro binary"

  def install
    if Hardware::CPU.arm?
      bin.install "lintro-macos-arm64" => "lintro"
    else
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

      # Install the package itself. Homebrew's pip_install runs pip with
      # --no-deps; the dependency closure of lintro[mcp] is the
      # pinned resource set above.
      venv.pip_install_and_link "#{buildpath}[mcp]"
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
