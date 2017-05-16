class LinuxmainGenerator < Formula
  desc "Shell command to keep SPM tests in sync on OSX and Linux."
  homepage "https://github.com/valeriomazzeo/linuxmain-generator"
  url "https://github.com/valeriomazzeo/homebrew-linuxmain-generator/archive/0.2.0.tar.gz"
  version "0.2.0"
  sha256 "50e0ec57794191b830fd2c69aff8bbfd65989d0c837809b68035bcafd9e8da09"

  def install
    ENV["CC"] = ""
    system "swift", "build", "-c", "release"
    bin.install ".build/release/linuxmain-generator"
  end
end
