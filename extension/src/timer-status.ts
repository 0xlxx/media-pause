import { showHUD } from "@raycast/api";
import { BinaryNotFoundError, runMediaPause } from "./lib/media-pause";

export default async function Command() {
  try {
    const res = await runMediaPause(["status"]);
    if (res.code !== 0) {
      await showHUD("⚠ 查询失败：" + (res.stderr.trim() || res.stdout.trim() || "未知错误"));
      return;
    }
    const out = res.stdout.trim();
    if (out.includes("No timer running")) {
      await showHUD("⏹ 没有运行中的计时器");
      return;
    }
    // Timer running · pause · Chrome
    // Remaining: 00:19:57
    const modeLine = out.split("\n")[0]?.trim() ?? "";
    const remaining = out
      .split("\n")
      .find((line) => line.startsWith("Remaining:"))
      ?.replace("Remaining:", "")
      .trim();
    await showHUD(`⏳ 剩余 ${remaining ?? "?"} · ${modeLine}`);
  } catch (error) {
    if (error instanceof BinaryNotFoundError) {
      await showHUD("⚠ " + error.message);
    } else {
      await showHUD("⚠ 执行失败：" + String(error));
    }
  }
}
