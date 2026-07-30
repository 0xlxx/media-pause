class MediaPause < Formula
  desc "macOS countdown timer that pauses browser media"
  homepage "https://github.com/0xlxx/media-pause"
  url "https://github.com/0xlxx/media-pause/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "c0d5b8b36b6191f1e39afac8279275c9d0b5e56c07d5fdf440d1cd12b847f9d4"
  license "MIT"
  version "0.2.0"
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
