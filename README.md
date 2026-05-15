# media-pause

macOS 倒计时结束后暂停浏览器标签页中所有视频/音频播放。

## 安装

```bash
swiftc -O -o media-pause main.swift
ln -sf "$PWD/media-pause" ~/bin/media-pause
```

要求 macOS 自带 Swift 工具链，无需额外依赖。

## 用法

```
media-pause [选项] [时长]
```

### 模式

| 标志 | 说明 |
|------|------|
| (默认) | 倒计时结束后暂停所有标签页媒体 |
| `-r, --resume` | 恢复播放（可带时长：恢复 → 倒计时 → 再暂停） |
| `-p, --playpause` | 倒计时结束后发送系统媒体键（对所有 App 生效） |
| `-m, --mute` | 倒计时结束后静音所有发声标签页 |
| `-q, --quit` | 倒计时结束后退出浏览器 |
| `-b, --browser` | 指定浏览器（chrome/brave/edge/arc/chromium/opera/vivaldi，默认 chrome） |

### 时长格式

`3600`（秒）、`1h`、`30m`、`1h30m`、`2h15m30s`

### 示例

```bash
media-pause 45m              # 45 分钟后暂停媒体
media-pause -r               # 立即恢复上次暂停的媒体
media-pause -r 10s           # 恢复播放 10 秒后再暂停
media-pause -b brave 30m     # 30 分钟后暂停 Brave 的媒体
media-pause -b edge -q 1h    # 1 小时后退出 Edge
media-pause -m 1h            # 1 小时后静音所有发声标签页
media-pause -p 30m           # 30 分钟后发送媒体键（Spotify、IINA 等也可用）
```

计时过程中按**空格**暂停/恢复，**Ctrl+C** 取消。

## 前置条件

pause/resume/mute 模式需要浏览器开启：

> View → Developer → **Allow JavaScript from Apple Events**

工具会在启动时自动检测此设置，未开启时会给出引导提示。

## 许可

MIT
