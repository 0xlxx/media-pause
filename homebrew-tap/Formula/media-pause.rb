class MediaPause < Formula
  desc "High-performance macOS countdown timer that pauses browser media"
  homepage "https://github.com/bjorn/media-pause"
  url "https://github.com/bjorn/media-pause/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "TODO: run `brew fetch --build-from-source Formula/media-pause.rb` to get checksum for release tarball"
  license "MIT"
  head "https://github.com/bjorn/media-pause.git", branch: "main"

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
