#!/bin/bash
# Shared helpers for media-pause Raycast scripts.
# Must stay bash 3.2 compatible (macOS default bash): no associative arrays,
# no readarray/mapfile.

# Directory containing this file (the Raycast script directory).
mp_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# Locate the media-pause binary WITHOUT relying on PATH. Raycast runs scripts
# with a minimal PATH (it only appends /usr/local/bin, no ~/bin and no
# /opt/homebrew/bin), so we search known install locations explicitly, then
# fall back to PATH.
mp_binary() {
    local script_dir mp
    script_dir="$(mp_script_dir)"
    # ~/bin first: the dev install (v4+). Homebrew may still carry the old
    # v3 binary, which lacks `status`/`stop` — never prefer it.
    local candidates=(
        "$HOME/bin/media-pause"
        "$HOME/.local/bin/media-pause"
        "/usr/local/bin/media-pause"
        "/opt/homebrew/bin/media-pause"
        "$script_dir/../.build/release/media-pause"
        "$script_dir/../.build/debug/media-pause"
    )
    for mp in "${candidates[@]}"; do
        if [ -x "$mp" ]; then
            printf '%s\n' "$mp"
            return 0
        fi
    done
    if command -v media-pause >/dev/null 2>&1; then
        command -v media-pause
        return 0
    fi
    return 1
}

# Resolve the binary path (stdout) or print a build hint to stderr and
# return non-zero. Callers: MP="$(mp_require)" || exit 1
mp_require() {
    local bin script_dir
    bin="$(mp_binary)" || {
        script_dir="$(mp_script_dir)"
        echo "⚠ media-pause binary not found." >&2
        echo "Build it first:" >&2
        echo "  cd '$script_dir/..' && swift build -c release" >&2
        echo "  ln -sf \"\$PWD/.build/release/media-pause\" ~/bin/media-pause" >&2
        return 1
    }
    printf '%s\n' "$bin"
}
