# media-pause

macOS 高性能倒计时媒体暂停工具。计时结束后通过 AppleScript + JavaScript 注入暂停 Chromium 浏览器的媒体播放，支持 30fps Unicode 动画进度条、颜色渐变、计时过程中空格键随时暂停/恢复。

## 特性

- **倒计时媒体控制** — 计时结束后暂停浏览器标签页中的所有 `<video>` 和 `<audio>` 元素
- **30fps 平滑动画** — Unicode 部分方块进度条 + Braille 转轮 + 颜色渐变（蓝→黄→红）
- **空格热键** — 计时过程中按空格键立即切换播放/暂停，计时器随之暂停/恢复
- **多模式** — 暂停、恢复、静音、退出浏览器、系统媒体键
- **7 种浏览器** — Chrome、Brave、Edge、Arc、Chromium、Opera、Vivaldi
- **防系统休眠** — 计时期间禁止 App Nap，确保精度
- **TTY 自适应** — 管道/重定向时自动降级为纯文本输出

## 安装

```bash
# 编译
swiftc -O -o media-pause main.swift

# 放到 PATH 中（Raycast 等启动器可发现）
ln -sf "$PWD/media-pause" ~/bin/media-pause
```

## 用法

```
media-pause [选项] [时长]
```

### 模式

| 标志 | 说明 |
|------|------|
| (默认) | 倒计时后暂停所有标签页的媒体 |
| `-r, --resume` | 恢复播放（可带时长：恢复→倒计时→再暂停） |
| `-p, --playpause` | 倒计时后发送系统媒体键（对所有 App 生效） |
| `-m, --mute` | 倒计时后静音所有发声标签页 |
| `-q, --quit` | 倒计时后退出浏览器 |
| `-b, --browser` | 指定浏览器（默认 chrome） |

### 时长格式

```
3600      秒
1h        小时
30m       分钟
1h30m     组合
```

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

### 计时过程中

| 按键 | 行为 |
|------|------|
| **空格** | 暂停/恢复计时器 + 媒体 |
| **Ctrl+C** | 取消 |

## 前置条件

对于 pause/resume/mute 模式，浏览器需要启用：

> View → Developer → **Allow JavaScript from Apple Events**

工具会在启动时自动检测此设置，未启用时会给出引导提示。

## 技术

- 纯 Swift，单文件，零依赖
- `NSAppleScript` + JavaScript 注入操作浏览器标签页
- 部分方块 Unicode 字符实现平滑进度条（`▏▎▍▌▋▊▉█`）
- 24-bit ANSI 颜色渐变
- `CGEvent` 发送系统媒体键
- `ProcessInfo.beginActivity` 防止 App Nap 导致计时漂移

## 许可

MIT
