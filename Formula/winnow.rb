# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Organize, deduplicate, and keep the best from your media library"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/4b/94/91fc97645693ad1bf09edcc31a912dec1c6351ff1448410bad9892d136e8/winnow_media-0.15.0.tar.gz"
  sha256 "1faa10eb2eab4334715bbd206daa2fd39bc9f4288a41e6241fc62b3ccce01038"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  # CLI tools installed via Homebrew
  depends_on "python@3.13"

  # Pure Python library dependencies
  resource "annotated-types" do
    url "https://files.pythonhosted.org/packages/ee/67/531ea369ba64dcff5ec9c3402f9f51bf748cec26dde048a2f973a4eea7f5/annotated_types-0.7.0.tar.gz"
    sha256 "aff07c09a53a08bc8cfccb9c85b05f1aa9a2a6f23728d790723543408344ce89"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/76/d4/81420972a676e8ffea40450d8c8c92943e7218a78fe9b64359836cc9876b/click-8.4.2.tar.gz"
    sha256 "9a6cea6e60b17ebe0a44c5cc636d94f09bd66142c1cd7d8b4cd731c4917a15f6"
  end

  resource "dynaconf" do
    url "https://files.pythonhosted.org/packages/2e/fa/351d165f6f9fe493a92a2e155f3097a4379dbe23e731b68543ce9988ee19/dynaconf-3.3.2.tar.gz"
    sha256 "3b50232b774142702c3d4623633bcd76bb9951abf8567b7f1340d73a30a80899"
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

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/18/a5/b60d21ac674192f8ab0ba4e9fd860690f9b4a6e51ca5df118733b487d8d6/pydantic-2.13.4.tar.gz"
    sha256 "c40756b57adaa8b1efeeced5c196f3f3b7c435f90e84ea7f443901bec8099ef6"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/c3/b2/bc9c9196916376152d655522fdcebac55e66de6603a76a02bca1b6414f6c/pygments-2.20.0.tar.gz"
    sha256 "6757cd03768053ff99f3039c1a36d6c0aa0b263438fcab17520b30a303a82b5f"
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
    url "https://files.pythonhosted.org/packages/96/59/8a8cb2331e2602b53e4dc06960f57d1387a2b18e7efd24e5f9cb60ea4925/tinytag-2.2.1.tar.gz"
    sha256 "e6d06610ebe7cd66fd07be2d3b9495914ab32654a5e47657bb8cd44c2484523c"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
    sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/55/e3/70399cb7dd41c10ac53367ae42139cf4b1ca5f36bb3dc6c9d33acdb43655/typing_inspection-0.4.2.tar.gz"
    sha256 "ba561c48a67c5958007083d386c3295464928b01faa735ab8547c5692e87f464"
  end

  # numpy requires native compilation - use platform-specific wheels
  resource "numpy" do
    on_arm do
      url "https://files.pythonhosted.org/packages/ab/ab/ddb499fc4f8780354395face5b65c7fd107bcd6e1d667a5f07d046956f6f/numpy-2.5.1-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "30b44a6b53a7ae63c54c089a8726e5563ed302716c5b7ccc85afade40b0e7ff6"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/eb/07/ec2a3f0c91761581d4b7104a740791800025983f9a4dc4e73f91a99aeac4/numpy-2.5.1-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "0bfebd8695f9863592fe744be833a258120b14a9f39da255e8aa8fade2c0ddd1"
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
      url "https://files.pythonhosted.org/packages/55/c0/e4d9b5570ee70f12c817722df398cdcba7fb25f4ddc691a79008a31c653d/pillow_heif-1.4.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "8f90b500ec1ae3a59d6613fd96123de35457f69fb9b3cd314d4b5a6799ba9843"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/79/d4/d15e568b61f6020b1a772174b5c9c60341a1f0130951c518d33461b36bf8/pillow_heif-1.4.0-cp313-cp313-macosx_10_15_x86_64.whl"
      sha256 "c699f8a3e845839bba590d3459ce59dba16c82c38e799955bef7042c54443eba"
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
      url "https://files.pythonhosted.org/packages/02/73/0291a64843270f4efb86cdcf2ee0f2048631b65ec6b405398b2b4dbf11bf/scipy-1.18.0-cp313-cp313-macosx_12_0_arm64.whl"
      sha256 "5efe260f69417b97ddae455bfb5a95e8359f7f66ad7fa9522a60feb66f169520"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/05/52/9c0136c2de7ae0779b7b366447766cec6d9f0702c56bb8ffeb04c8fd3af4/scipy-1.18.0-cp313-cp313-macosx_10_15_x86_64.whl"
      sha256 "09143f676d157d9f546d663504ef9c1becb819824f1afc018814176411942446"
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
