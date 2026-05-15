class MediaPause < Formula
  desc "macOS countdown timer that pauses browser media"
  homepage "https://github.com/0xlxx/media-pause"
  url "https://github.com/0xlxx/media-pause/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "d64db7ae21297d0e6290af6a3e0a781a2a64376fab7461ea62ff59c27ea0d615"
  license "MIT"
  version "0.1.1"
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
