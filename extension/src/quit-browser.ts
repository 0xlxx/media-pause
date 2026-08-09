import { showHUD } from "@raycast/api";
import { BinaryNotFoundError, runMediaPause, startBackgroundTimer } from "./lib/media-pause";

interface Arguments {
  duration?: string;
  browser?: string;
}

export default async function Command(props: { arguments: Arguments }) {
  const browser = (props.arguments.browser ?? "chrome").trim();
  const duration = props.arguments.duration?.trim();

  try {
    if (duration) {
      startBackgroundTimer(["-q", "-b", browser, duration]);
      await showHUD(`⏳ 已启动 ${duration} 倒计时，到点退出 ${browser}`);
      return;
    }
    const res = await runMediaPause(["--now", "-q", "-b", browser]);
    await showHUD(res.code === 0 ? "🚫 已退出浏览器" : "⚠ 退出失败（浏览器未运行？）");
  } catch (error) {
    if (error instanceof BinaryNotFoundError) {
      await showHUD("⚠ " + error.message);
    } else {
      await showHUD("⚠ 执行失败：" + String(error));
    }
  }
}
