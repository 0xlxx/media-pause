class MediaPause < Formula
  desc "macOS countdown timer that pauses browser media"
  homepage "https://github.com/0xlxx/media-pause"
  url "https://github.com/0xlxx/media-pause/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "6a628322fbf2c5d8952610248ef30f0cd9ad6bbdc938536593ae739003b6d6f9"
  license "MIT"
  version "0.1.3"
  head "https://github.com/0xlxx/media-pause.git", branch: "main"

  depends_on :macos
  uses_from_macos "swift" => :build

  def install
    system "swiftc", "-O", "-o", "media-pause", "main.swift"
    bin.install "media-pause"
  end

  test do
    assert_match "media-pause", shell_output("#{bin}/media-pause --version")
  end
end
