class MediaPause < Formula
  desc "macOS countdown timer that pauses browser media"
  homepage "https://github.com/0xlxx/media-pause"
  url "https://github.com/0xlxx/media-pause/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "f6bb2ff9d2b3b0b528f69481bacc4c23b176380a1cac712ad648e3114d48d339"
  license "MIT"
  version "0.1.2"
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
