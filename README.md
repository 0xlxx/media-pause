# media-pause

macOS 倒计时结束后暂停浏览器标签页中所有视频/音频播放。

## 安装

### Homebrew (推荐)

```bash
brew install bjorn/homebrew-tap/media-pause
```

### 手动安装

```bash
swiftc -O -o media-pause main.swift
ln -sf "$PWD/media-pause" ~/bin/media-pause
```

要求 macOS 自带 Swift 工具链，无需额外依赖。

### Raycast 集成

将 `raycast/` 目录添加到 Raycast 脚本目录：

1. Raycast 设置 → Extensions → 点击 `+` → Script Directory
2. 选择本仓库的 `raycast/` 目录

**可用命令**（搜索即路由）：

| 命令 | 用途 | 参数 |
|------|------|------|
| `Pause Media` | 倒计时后暂停媒体 | 时长（默认 1h）、浏览器（默认记住上次） |
| `Resume Media` | 恢复播放（可选倒计时） | 时长（可选）、浏览器 |
| `Mute Tabs` | 倒计时后静音标签页 | 时长（默认 1h）、浏览器 |
| `Quit Browser` | 倒计时后退出浏览器 | 时长（默认 1h）、浏览器 |
| `Play/Pause Key` | 发送系统媒体键 | 时长（默认 1h） |
| `Timer Status` | 查看运行中计时器的进度 | 无参数，显示进度条 + 剩余/已用时间 |
| `Timer Stop` | 停止当前运行的计时器 | 无参数 |

- 浏览器自动检测已安装的，未安装的自动过滤
- 首次使用会记住浏览器选择，下次直接回车
- 同时只能运行一个计时器，重复运行会提示先停止
- `Timer Stop` 可随时手动停止
- 开始和完成时弹出系统通知
- 计时在后台运行，不影响工作

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
| `-b, --browser` | 指定浏览器，支持逗号分隔 (`chrome,brave`)、重复 (`-b chrome -b brave`) 和 `all`，默认 chrome |

### 时长格式

`3600`（秒）、`1h`、`30m`、`1h30m`、`2h15m30s`

### 示例

```bash
media-pause 45m              # 45 分钟后暂停媒体
media-pause -r               # 立即恢复上次暂停的媒体
media-pause -r 10s           # 恢复播放 10 秒后再暂停
media-pause -b brave 30m     # 30 分钟后暂停 Brave 的媒体
media-pause -b chrome,brave 30m  # 同时暂停 Chrome 和 Brave
media-pause -b all 30m       # 暂停所有已安装浏览器的媒体
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
