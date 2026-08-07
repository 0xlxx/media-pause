class MediaPause < Formula
  desc "macOS countdown timer that pauses and resumes browser media"
  homepage "https://github.com/0xlxx/media-pause"
  # TODO: update sha256 when v4.0.0 is tagged.
  url "https://github.com/0xlxx/media-pause/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  version "4.0.0"
  head "https://github.com/0xlxx/media-pause.git", branch: "main"

  depends_on :macos
  uses_from_macos "swift" => :build

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/media-pause"
  end

  test do
    assert_match "media-pause", shell_output("#{bin}/media-pause --version")
  end
end
