# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Organize, deduplicate, and keep the best from your media library"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/5b/9e/474589d93af5b589885a40af3a30486fded5ad2f447607bd53f2ab6471ac/winnow_media-0.19.0.tar.gz"
  sha256 "d64b26bf54ee958aaa24a87ae7c643d13717d97384d13dc380a634ef333266db"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "python@3.13"

  # Pure Python library dependencies
  resource "annotated-types" do
    url "https://files.pythonhosted.org/packages/5f/56/a8120250d128bed162cd73c76d45f6ef9991f3e068f62a8ee060afa3104a/annotated_types-0.8.0.tar.gz"
    sha256 "13b2beaad985e05e2d6407ee4c4f35590b11f8d693a258a561055cac8f64cab7"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/c7/0e/7fa0ef50764b67090eca4114772a2abf8b6148198475e54c660b97caeee6/click-8.5.0.tar.gz"
    sha256 "ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34"
  end

  resource "dynaconf" do
    url "https://files.pythonhosted.org/packages/71/e4/723ba469856bb493c948985e5bd562c8a65f2b93e70c896e9764ab76de00/dynaconf-3.3.5.tar.gz"
    sha256 "a08f6ab44025034ef3c9f86b32548ab01efd4039094a74bd9f028a43c63d016f"
  end

  resource "exifread" do
    url "https://files.pythonhosted.org/packages/e2/4e/d8fce8810d819db47f5b159e75223511c5ccd7ad07c2feca64cf7fab2477/exifread-3.5.1.tar.gz"
    sha256 "9f998f80d3062741c976dfc4fd033424bc40932937994e4d2181eb70c4b6aedd"
  end

  resource "imagehash" do
    url "https://files.pythonhosted.org/packages/cd/de/5c0189b0582e21583c2a213081c35a2501c0f9e51f21f6a52f55fbb9a4ff/ImageHash-4.3.2.tar.gz"
    sha256 "e54a79805afb82a34acde4746a16540503a9636fd1ffb31d8e099b29bbbf8156"
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

  resource "mutagen" do
    url "https://files.pythonhosted.org/packages/df/70/1675da133ea92227da41bf5b24e1c66be597ff736a1533ade41da986852f/mutagen-1.48.1.tar.gz"
    sha256 "8f95637ab9f6f305cec6bd1294e197debe207998e3e068596563c74f86b0a173"
  end

  resource "puremagic" do
    url "https://files.pythonhosted.org/packages/24/74/ce5987ab9b8aec4ced06e2723ebb604205c9eb58abdad91453da93166380/puremagic-2.2.0.tar.gz"
    sha256 "eb4bddf07c177c4b434554b92165b67449f5a51e152b976202d6254498810eef"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/18/a5/b60d21ac674192f8ab0ba4e9fd860690f9b4a6e51ca5df118733b487d8d6/pydantic-2.13.4.tar.gz"
    sha256 "c40756b57adaa8b1efeeced5c196f3f3b7c435f90e84ea7f443901bec8099ef6"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz"
    sha256 "610ca751c9bc2492b38eb9a38a7fbc93edbbb2d7182edaf34e66ae493dee5c8c"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/c0/8f/0722ca900cc807c13a6a0c696dacf35430f72e0ec571c4275d2371fca3e9/rich-15.0.0.tar.gz"
    sha256 "edd07a4824c6b40189fb7ac9bc4c52536e9780fbbfbddf6f1e2502c31b068c36"
  end

  resource "ruamel-yaml" do
    url "https://files.pythonhosted.org/packages/c7/3b/ebda527b56beb90cb7652cb1c7e4f91f48649fbcd8d2eb2fb6e77cd3329b/ruamel_yaml-0.19.1.tar.gz"
    sha256 "53eb66cd27849eff968ebf8f0bf61f46cdac2da1d1f3576dd4ccee9b25c31993"
  end

  resource "tinytag" do
    url "https://files.pythonhosted.org/packages/9f/a4/a1d39cc10b43cbbae268127a1c38d689bc6a85cf966f9445bc9f1f5f517a/tinytag-2.3.0.tar.gz"
    sha256 "84850f8045424b944475b9754bc35c7e09bcae1ab08d1f88d9293aa33af39a27"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
    sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/a3/26/b09b8010994eccc3c09092e6b34058f36a460eea2d4c3e8b910c695975a0/typing_inspection-0.4.4.tar.gz"
    sha256 "547274fa6b0a561ccf549cc9524b999a578e737d015d8709d021f9d0d13bea47"
  end

  # numpy requires native compilation - use platform-specific wheels
  resource "numpy" do
    on_arm do
      url "https://files.pythonhosted.org/packages/65/60/f2d208d366f263f39c6e69ed309290717aab41078b6d04c9be2a84fa2a07/numpy-2.5.2-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "52c808f96484f5571a5cc863775ce50247c17dfb3b0361f8ed6b4b0456f80080"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/f5/d2/6b24738a0ef4557d189b150046cd07823c50e4273e8aebd651222e24306f/numpy-2.5.2-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "8e4cb9a754c8a0c62eaa88273a5fba3391f4a610d1dee893c0755da31c083f15"
    end
  end
  # pillow requires native compilation - use platform-specific wheels
  resource "pillow" do
    on_arm do
      url "https://files.pythonhosted.org/packages/10/76/8803c13605b763d33d156c4678fc77f8443389c0c51c8aef707bb02015f4/pillow-12.3.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "d69141514cc30b774ceea5e3ed3a6635c8d8a96edf664689b890f4089111fb35"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/42/92/2fc3ffad878ae8dd5469ec1bc8eb83b71f48e13efdf68f02709003982a32/pillow-12.3.0-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "7a743ff716f746fc19a9557f60dab1600d4613255f8a7aeb3cdde4db7eb15a66"
    end
  end
  # pillow_heif bundles libheif and needs it to build from source - use platform-specific wheels
  resource "pillow_heif" do
    on_arm do
      url "https://files.pythonhosted.org/packages/e3/4f/a9f2e1525655c93e9b72cec3792a41f7d732222dad1d329fa04c227cbe28/pillow_heif-1.5.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "a6d7c9dd6f490c433267ab9b66b63961e59a4c04c9d0e38ba66e4b6664d5e7d8"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/33/92/502ae6bebaf1fc48850f690858040932fb6fe0bd0de25b5e715df2517d14/pillow_heif-1.5.0-cp313-cp313-macosx_10_15_x86_64.whl"
      sha256 "b736040d566271143c09bf87967549daf3d3090e9b4283ca2076c3383ab141d8"
    end
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
  # pywavelets requires native compilation - use platform-specific wheels
  resource "pywavelets" do
    on_arm do
      url "https://files.pythonhosted.org/packages/aa/0c/b54b86596c0df68027e48c09210e907e628435003e77048384a2dd6767e3/pywavelets-1.9.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "c50320fe0a4a23ddd8835b3dc9b53b09ee05c7cc6c56b81d0916f04fc1649070"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/db/a7/dec4e450675d62946ad975f5b4d924437df42d2fae46e91dfddda2de0f5a/pywavelets-1.9.0-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "74f8455c143818e4b026fc67b27fd82f38e522701b94b8a6d1aaf3a45fcc1a25"
    end
  end
  # scipy requires native (C/Fortran) compilation - use platform-specific wheels
  resource "scipy" do
    on_arm do
      url "https://files.pythonhosted.org/packages/2a/f5/769f36d14922b8071a43e95d24d18b6bdafad10d7f5cf647867e1ac052bc/scipy-1.18.1-cp313-cp313-macosx_12_0_arm64.whl"
      sha256 "e6fb6a55cc0ba97b59a1f288fb86dc6fce8bdfc0fffcbfd015e3a954bf2a2d93"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/b6/55/4540ee0f9c42a9ad7109d0d1a8cc70de54c3572b01c6693a2b1c70e90ceb/scipy-1.18.1-cp313-cp313-macosx_10_15_x86_64.whl"
      sha256 "3ab3523da44749156e1f68b464dc56af11ae4cbc5c739a49d05f32b982eca9f3"
    end
  end
  def install
    venv = virtualenv_create(libexec, "python3.13")

    # Install other resources first (this sets up pip in the venv)
    wheel_only = %w[numpy pillow pillow_heif pydantic_core pywavelets scipy]
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

  test do
    assert_match version.to_s, shell_output("#{bin}/winnow --version")
  end
end
