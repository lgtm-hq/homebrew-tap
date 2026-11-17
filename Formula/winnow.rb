# typed: strict
# frozen_string_literal: true

# Homebrew formula for winnow
# CLI tools are installed as Homebrew dependencies; Python libraries are bundled
class Winnow < Formula
  include Language::Python::Virtualenv

  desc "Organize, deduplicate, and keep the best from your media library"
  homepage "https://github.com/lgtm-hq/winnow"
  url "https://files.pythonhosted.org/packages/f2/f5/f82ae707302f5b6ebbb466bbb07260359de122dc7afc41e3c1004b2fbf4c/winnow_media-0.37.10.tar.gz"
  sha256 "77096fc4e05a458b045e750983625b419baa8570b66294c7c82089022a56c2df"
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
    url "https://files.pythonhosted.org/packages/45/37/edbf1b0707709013c0cf2e8317e03d97ed29bf4cac709fe328904ae92a38/click-8.5.1.tar.gz"
    sha256 "9bbfada76703fd1d784b83eea012e3e8c6a001a876543ef104fa56aaaeb072b4"
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

  resource "mutagen" do
    url "https://files.pythonhosted.org/packages/df/70/1675da133ea92227da41bf5b24e1c66be597ff736a1533ade41da986852f/mutagen-1.48.1.tar.gz"
    sha256 "8f95637ab9f6f305cec6bd1294e197debe207998e3e068596563c74f86b0a173"
  end

  resource "puremagic" do
    url "https://files.pythonhosted.org/packages/a7/8d/4d60110e23f445e2dc106340f9bd5f422bb6c540f4fb21086d3ee44b52ab/puremagic-2.3.0.tar.gz"
    sha256 "b54e4a69dd37c50bacc879380f132382ab4e9a935529628c8975abcc73e10640"
  end

  resource "pydantic" do
    url "https://files.pythonhosted.org/packages/b4/fc/1203d011145c98ddce3cd2f505bb54375ef8d43223053df6bfcf3c746f46/pydantic-2.14.3.tar.gz"
    sha256 "1054f237f4d4733e5a30e1e2333bd33a2004ab9ab1510bd053a9a31bb48e232d"
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
    url "https://files.pythonhosted.org/packages/38/0f/fae085b7f19fe0c67b68e6d70098ac6cd046cc498f253f5ee56a3dd03bbc/tinytag-2.3.2.tar.gz"
    sha256 "021d711cdbdbf840d3b67b976cb34dadc58d2fcfd490eb74ef9602b37b991414"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
    sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/ff/50/0195198eb1d75bab716bb0a813abea4cc394bfa17a92a189f021a34859af/typing_inspection-0.4.5.tar.gz"
    sha256 "7f16c411e7930dc79596d42ab44672a3fe5f60eb34b781a1647e7872363120c7"
  end

  # numpy requires native compilation - use platform-specific wheels
  resource "numpy" do
    on_arm do
      url "https://files.pythonhosted.org/packages/d4/9a/01a332ebb0899ddb14d782f86ed66d080463e5387a8778029462d1902019/numpy-2.5.5-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "7e71ac4284c700afa654e2d15b1b174166710dca932f24045e5dc92001b5bda0"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/0f/fa/4ae71d860267f2f9eaf7640516f693acf61c9575d48157cdea459c0215aa/numpy-2.5.5-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "228e3d90e967495d61ddc79dd64e95267aae3bcf1b1c516a6186429106a0b444"
    end
  end
  # pillow requires native compilation - use platform-specific wheels
  resource "pillow" do
    on_arm do
      url "https://files.pythonhosted.org/packages/98/c8/ccede3dcc4f274b80fb49199eed1ef34ba05566c8b71976b9d1f111da2e3/pillow-13.0.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "f11a3c1358bb3c68012a7b1f41b223c3db9f7bfde90b481df028cfe1c3363313"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/08/bc/578ab2eaa04705a8978bd9be0fe15c3d43a8fc95097c4f7e39540e79e4fa/pillow-13.0.0-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "ef5fe6b7db3f501c56000ba8fe7c7e1a35ca1d45824fbeb95a67daa85cff4dbe"
    end
  end
  # pillow_heif bundles libheif and needs it to build from source - use platform-specific wheels
  resource "pillow-heif" do
    on_arm do
      url "https://files.pythonhosted.org/packages/29/96/4170d91441cbb3336dbe02155b57c0004b2516a40538f7aae8c0b8af497d/pillow_heif-1.8.1-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "98c500475f3add0d2ac4a6686b925c22fd0cf05def1ce977fec8ec753dabd66a"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/8a/3a/6d395d48eca2914c8cc9b38d589c3e2c61e33ca531e3a7514dd359be85fb/pillow_heif-1.8.1-cp313-cp313-macosx_10_15_x86_64.whl"
      sha256 "05cc2b14203cdb9d0a1f44d47657fa2d2bf12f6fff8d2e2873c2a1d837198aa9"
    end
  end
  # pydantic_core requires Rust to build - use platform-specific wheels
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
  # pywavelets requires native compilation - use platform-specific wheels
  resource "pywavelets" do
    on_arm do
      url "https://files.pythonhosted.org/packages/cf/0f/3b2762f936510c0344ce8b97438720ee9f1879a83316410ba475bdeea463/pywavelets-1.10.0-cp313-cp313-macosx_11_0_arm64.whl"
      sha256 "4bfeaada62a12664626b21cfc41e5d0538b3c238dde22e78ea4769fac4bf6160"
    end
    on_intel do
      url "https://files.pythonhosted.org/packages/07/dd/6db37a5c4d3e8c0ae7316384fa0cd52f8575c2e15d71a12d320f9dc4b2c3/pywavelets-1.10.0-cp313-cp313-macosx_10_13_x86_64.whl"
      sha256 "761af8d319c9c104969b1a92e0e9c41aad34ca98f229cf87060f202cd9e633eb"
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
    wheel_only = %w[numpy pillow pillow-heif pydantic-core pywavelets scipy]
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
