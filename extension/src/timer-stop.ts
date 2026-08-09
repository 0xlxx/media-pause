import { showHUD } from "@raycast/api";
import { BinaryNotFoundError, runMediaPause } from "./lib/media-pause";

export default async function Command() {
  try {
    const res = await runMediaPause(["stop"]);
    const out = res.stdout.trim();
    if (out.includes("No timer running")) {
      await showHUD("⏹ 没有运行中的计时器");
      return;
    }
    await showHUD(res.code === 0 ? "⏹ 计时器已停止" : "⚠ 停止失败：" + out);
  } catch (error) {
    if (error instanceof BinaryNotFoundError) {
      await showHUD("⚠ " + error.message);
    } else {
      await showHUD("⚠ 执行失败：" + String(error));
    }
  }
}
