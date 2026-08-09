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
      // CLI: resume now, then auto-pause after `duration`.
      startBackgroundTimer(["-r", "-b", browser, duration]);
      await showHUD(`▶ 已恢复播放，${duration} 后自动暂停`);
      return;
    }
    const res = await runMediaPause(["-r", "-b", browser]);
    await showHUD(res.code === 0 ? "▶ 已恢复播放" : "⚠ 恢复失败，请打开终端查看详情");
  } catch (error) {
    if (error instanceof BinaryNotFoundError) {
      await showHUD("⚠ " + error.message);
    } else {
      await showHUD("⚠ 执行失败：" + String(error));
    }
  }
}
