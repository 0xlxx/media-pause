#!/bin/bash
# One-time helper: add the media-pause Raycast script directory.
#
#   bash scripts/install-raycast.sh
#
# It checks the binary, opens the `raycast/` folder in Finder, and prints the
# steps to register it. Works for both Raycast stable and Raycast 2.0 Beta
# (the two apps are independent — register the directory in whichever you use).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAYCAST_DIR="$ROOT/raycast"

# shellcheck disable=SC1091
source "$RAYCAST_DIR/_media-pause-lib.sh"

echo "── media-pause Raycast 集成 ──"
MP="$(mp_require)" || exit 1
echo "✓ 二进制: $MP"
echo "  版本:   $("$MP" --version)"

echo ""
echo "接下来在 Raycast（或 Raycast Beta）中："
echo "  1. 打开设置 Settings → Extensions"
echo "  2. 点击右下角 +  →  Add Script Directory"
echo "  3. 选择目录: $RAYCAST_DIR"
echo ""
echo "添加后即可搜索: Pause Media / Resume Media / Timer Status / Timer Stop ..."

if [ "${1:-}" != "--no-open" ]; then
    echo ""
    echo "已在 Finder 中打开脚本目录…"
    open "$RAYCAST_DIR"
fi
