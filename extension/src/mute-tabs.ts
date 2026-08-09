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
      startBackgroundTimer(["-m", "-b", browser, duration]);
      await showHUD(`⏳ 已启动 ${duration} 倒计时，到点静音 ${browser}`);
      return;
    }
    const res = await runMediaPause(["--now", "-m", "-b", browser]);
    await showHUD(res.code === 0 ? "🔇 已静音标签页" : "⚠ 静音失败，请打开终端查看详情");
  } catch (error) {
    if (error instanceof BinaryNotFoundError) {
      await showHUD("⚠ " + error.message);
    } else {
      await showHUD("⚠ 执行失败：" + String(error));
    }
  }
}
