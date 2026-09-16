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
      url "https://github.com/lgtm-hq/py-lintro/releases/download/v0.161.0/lintro-macos-arm64"
      sha256 "baed49b8b443ed04bd624912b49d60a5fbd8d5c7f0ee06467ca77b54d856ef98"
    end
    on_intel do
      # No x86_64 release binary is published (lgtm-hq/py-lintro#2579), so
      # Intel Macs install the same version from the PyPI sdist into a
      # Homebrew Python virtualenv. Every Python dependency is a url+sha256
      # pinned resource below; nothing is resolved from PyPI at install time.
      url "https://files.pythonhosted.org/packages/b6/8e/d2378b0be0598a4f0051bd8a3a3414b75acc159656bc7fcf41eb247ef747/lintro-0.161.0.tar.gz"
      sha256 "ffe478a84dd90b8e6b0595fe50cb70ee2150c62a656e7cef423f1182c492dc8d"

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
        url "https://files.pythonhosted.org/packages/a3/c2/24167ea9858356b47a87a50d39908bfdb72ceeefe0041586e704e5376b3a/certifi-2026.7.22.tar.gz"
        sha256 "741e2c3b351ddf169a738da9f2c048608ff7f2c5cc02f1ebc6b118bb090d5d55"
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
        url "https://files.pythonhosted.org/packages/bb/ad/5d6702db60b1e40b41ef513b6967ff5848f307d50f8449baf1634f5908f1/cryptography-50.0.1.tar.gz"
        sha256 "5dd9bda1c12b4162f6ff568eeb5e0ff956c28d14406e875cfe8a63a2d414ff20"
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
        url "https://files.pythonhosted.org/packages/15/8c/e925b1c92018abb3a1863ce1549d76d2381e334d21d65d4ac8f65dabd78a/httpcore2-2.13.0.tar.gz"
        sha256 "2adc8be4fb285fbcd6d894298db3b52c177e74b6674eda3a76bd36be3292a3db"
      end

      resource "httpx" do
        url "https://files.pythonhosted.org/packages/b1/df/48c586a5fe32a0f01324ee087459e112ebb7224f646c0b5023f5e79e9956/httpx-0.28.1.tar.gz"
        sha256 "75e98c5f16b0f35b567856f597f06ff2270a374470a5c2392242528e3e3e42fc"
      end

      resource "httpx2" do
        url "https://files.pythonhosted.org/packages/b9/a0/e9deef4654132857b5a5dbe4eddd0ac59c2814500e11f2f5044cd81103ee/httpx2-2.13.0.tar.gz"
        sha256 "81bd07dc67a3701729ef1f777a3c00c915d4539604fdb5afd327f8682f6b7b44"
      end

      resource "identify" do
        url "https://files.pythonhosted.org/packages/52/63/51723b5f116cc04b061cb6f5a561790abf249d25931d515cd375e063e0f4/identify-2.6.19.tar.gz"
        sha256 "6be5020c38fcb07da56c53733538a3081ea5aa70d36a156f83044bfbf9173842"
      end

      resource "idna" do
        url "https://files.pythonhosted.org/packages/5f/f7/abb373e5757eaec4b922b92f97ec8d6d7e057cf06778247604fbc4e7c3f3/idna-3.19.tar.gz"
        sha256 "5e0811a4383b21dc5838069f801c4fb62113b7447663d2530d2bd6e77b49bf15"
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
        url "https://files.pythonhosted.org/packages/76/31/ac54fb0fdd5b37de704486e288bba4fbbb463f24cfcfedbede407b854513/mcp-2.2.0.tar.gz"
        sha256 "2dc37ecb1974becdcebdbf7561e7c15a07dbbf20ba21ba16c3593b3038b3afbd"
      end

      resource "mcp-types" do
        url "https://files.pythonhosted.org/packages/ae/91/762d7755d971aff8a28d75f7961656148edf27875c8026e6385aaab08ae7/mcp_types-2.2.0.tar.gz"
        sha256 "d3ed53703ddd10d9c6399f29d322bb66f3f67ab41348ac8556ba23e07fedefad"
      end

      resource "mdurl" do
        url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
        sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
      end

      resource "opentelemetry-api" do
        url "https://files.pythonhosted.org/packages/ee/8b/aa9e2d8b8dfa7c946f7dec5d1f8f6ba8eca062f43509a06bdb5ce93d26c0/opentelemetry_api-1.44.0.tar.gz"
        sha256 "67647e5e9566edcf421166fdf022b3537f818635daa852b289e34604dc6fb33a"
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
        url "https://files.pythonhosted.org/packages/1b/7d/92392ff7815c21062bea51aa7b87d45576f649f16458d78b7cf94b9ab2e6/pycparser-3.0.tar.gz"
        sha256 "600f49d217304a5902ac3c37e1281c9fe94e4d0489de643a9504c5cdfdfc6b29"
      end

      resource "pydantic" do
        url "https://files.pythonhosted.org/packages/53/ef/fc4f868f4e2cee79f863883abffceff107875f569b848507319842d2a681/pydantic-2.13.5.tar.gz"
        sha256 "51a9c5f7b2f8e636f04c6cada605d9b6a3bf1348fdf945a3d8869b19bba0ee08"
      end

      resource "pygments" do
        url "https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz"
        sha256 "610ca751c9bc2492b38eb9a38a7fbc93edbbb2d7182edaf34e66ae493dee5c8c"
      end

      resource "pyjwt" do
        url "https://files.pythonhosted.org/packages/af/c3/8a3b59c25070cc61dc517fbdfa5dc0904670c96f605cc69759dc09166b99/pyjwt-2.14.0.tar.gz"
        sha256 "77283c83fb56ecf566a886c757a714bc83668e38156de2cce8263302f42e0b86"
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
        url "https://files.pythonhosted.org/packages/aa/2a/9618a122aeb2a169a28b03889a2995fe297588964333d4a7d67bdf46e147/rpds_py-2026.6.3.tar.gz"
        sha256 "1cebd1337c242e4ec2293e541f712b2da849b29f48f0c293684b71c0632625d4"
      end

      resource "sse-starlette" do
        url "https://files.pythonhosted.org/packages/2b/54/6767bb789b2f2fed6e0f953df949cd39dc263a384c1b65a95232598621d6/sse_starlette-3.4.11.tar.gz"
        sha256 "1bae716c02f3e6f294be41ff333220692dae7c3cbab077c900f159676719dade"
      end

      resource "starlette" do
        url "https://files.pythonhosted.org/packages/b5/b4/205b0d5241d934e8add0c38aa924c4f9fb7330834ff11e5444db964ec3f9/starlette-1.6.0.tar.gz"
        sha256 "d4e3ac5e546444960c710297a3c9fc3f7ebae1b7e963f3d36173b49da535be9b"
      end

      resource "tabulate" do
        url "https://files.pythonhosted.org/packages/46/58/8c37dea7bbf769b20d58e7ace7e5edfe65b849442b00ffcdd56be88697c6/tabulate-0.10.0.tar.gz"
        sha256 "e2cfde8f79420f6deeffdeda9aaec3b6bc5abce947655d17ac662b126e48a60d"
      end

      resource "truststore" do
        url "https://files.pythonhosted.org/packages/53/a3/1585216310e344e8102c22482f6060c7a6ea0322b63e026372e6dcefcfd6/truststore-0.10.4.tar.gz"
        sha256 "9d91bd436463ad5e4ee4aba766628dd6cd7010cf3e2461756b3303710eebc301"
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
        url "https://files.pythonhosted.org/packages/5d/ad/04bbb797c84fc1f26cb171f7394716f4865ffb8d8c5e1eef42565c2dfa6b/uvicorn-0.53.0.tar.gz"
        sha256 "a9356f0cb89b3b8621529c5d5eebd69bfe154f4c3f68b4cf2de47e45fa855c2e"
      end

      resource "watchdog" do
        url "https://files.pythonhosted.org/packages/db/7d/7f3d619e951c88ed75c6037b246ddcf2d322812ee8ea189be89511721d54/watchdog-6.0.0.tar.gz"
        sha256 "9ddf7c82fda3ae8e24decda1338ede66e1c99883db93711d8fb941eaa2d8c282"
      end

      # pydantic-core requires Rust to build - use platform-specific wheels
      resource "pydantic-core" do
        url "https://files.pythonhosted.org/packages/f5/37/5abe39a8372a61d3dc3c1338fc504281c01b32fdb3169cd7187153b56d3e/pydantic_core-2.46.5-cp313-cp313-macosx_10_12_x86_64.whl"
        sha256 "b7ca9034437b6022f941f4857459562ee00a560b97e7cce8a0ec5a74fc6766e0"
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
