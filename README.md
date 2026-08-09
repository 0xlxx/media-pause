# media-pause

macOS 上控制 Chrome 音视频的**定时暂停 / 恢复**工具。倒计时结束后暂停浏览器标签页中的全部音视频，也可立即暂停、恢复或"恢复播放 N 秒后再暂停"。

## 特性

- ⏸ **定时暂停**：`media-pause 45m` 倒计时后暂停 Chrome 所有标签页音视频
- ▶ **定时/即时恢复**：`-r` 立即恢复；`-r 10s` 恢复播放 10 秒后自动再暂停
- ⚡ **即时操作**：`--now` 跳过倒计时立即执行
- 🔀 **多通道降级**（诚实报告每个通道结果）：
  1. **CDP**（Chrome DevTools Protocol）——若 Chrome 以 `--remote-debugging-port=9222` 运行则优先，无需 Apple Events 权限
  2. **AppleScript JS**——逐标签页暂停/恢复 `<video>/<audio>`（需开启 *Allow JavaScript from Apple Events*，可用 `media-pause setup` 自动修复）
  3. **媒体键**——CGEvent 投递到浏览器实例
  4. **系统媒体键**——存在 Now Playing 会话时兜底
- 🌐 **多浏览器**：chrome / brave / edge / arc / chromium / opera / vivaldi（`-b all`）
- 🖥 终端倒计时（Space 暂停/恢复计时器与媒体，Ctrl+C 取消）、菜单栏倒计时、Raycast 命令
- 🧪 可测试：单元测试 + 编译测试 + 变异测试（见下文）

## 安装

### 从源码构建（开发）

```bash
swift build -c release --product media-pause
ln -sf "$PWD/.build/release/media-pause" ~/bin/media-pause
```

要求 macOS Swift 工具链（含 SwiftPM），无需 Xcode、无外部依赖。

### Homebrew

```bash
brew install 0xlxx/homebrew-tap/media-pause   # 待 v4.0.0 tag 后可用
```

### Raycast 集成（支持 Raycast 2.0 Beta）

把仓库的 `raycast/` 目录添加为 Raycast 的 **Script Directory**：

1. 先构建并安装二进制（一次性）：
   ```bash
   swift build -c release --product media-pause
   ln -sf "$PWD/.build/release/media-pause" ~/bin/media-pause
   ```
2. 运行辅助脚本（检查二进制 + 在 Finder 中打开脚本目录）：
   ```bash
   bash scripts/install-raycast.sh
   ```
3. 在 **Raycast / Raycast Beta** 中：设置 Settings → Extensions → 点 `+` → **Add Script Directory** → 选择本仓库的 `raycast/` 目录。

> Raycast stable 与 Raycast 2.0 Beta 是两个独立应用，需分别添加脚本目录。
> 脚本**不依赖 PATH**：Raycast 运行脚本的环境 PATH 很精简（官方只追加 `/usr/local/bin`，不含 `~/bin` 或 `/opt/homebrew/bin`），`raycast/_media-pause-lib.sh` 会显式在常见安装位置查找二进制。

**命令**（时长可选；浏览器为下拉选择）：

| 命令 | 用途 |
|------|------|
| `Pause Media` | 暂停媒体（无时长=立即暂停） |
| `Resume Media` | 恢复播放（可带时长，到时再暂停） |
| `Mute Tabs` | 倒计时后静音标签页（默认 1h） |
| `Quit Browser` | 倒计时后退出浏览器（默认 1h） |
| `Play/Pause Key` | 发送系统媒体键（默认 1h） |
| `Timer Status` | 查看运行中计时器进度 |
| `Timer Stop` | 停止当前计时器 |

### 菜单栏倒计时

```bash
bash menu-bar/build.sh
open menu-bar/CountdownTimer.app
```

## 用法

```
media-pause [options] [duration]
media-pause status | stop | setup
```

### 模式

| 标志 | 说明 |
|------|------|
| (默认) | 倒计时结束后暂停所有标签页媒体 |
| `-r, --resume` | 恢复播放（可带时长：恢复 → 倒计时 → 再暂停） |
| `-p, --playpause` | 发送系统媒体键（对所有 App 生效） |
| `-m, --mute` | 倒计时结束后静音所有发声标签页 |
| `-q, --quit` | 倒计时结束后退出浏览器 |
| `-b, --browser` | 指定浏览器（`chrome,brave`、`all`），默认 chrome |
| `-n, --now` | 立即执行，跳过倒计时 |

### 命令

| 命令 | 说明 |
|------|------|
| `status` | 查看运行中计时器（剩余/已用/模式） |
| `stop` | 停止运行中的计时器 |
| `setup` | 在所有 Chrome profile 中启用 *Allow JavaScript from Apple Events*（等价旧 `--fix-perms`） |

### 时长格式

`3600`（秒）、`1h`、`30m`、`1h30m`、`2h15m30s`

### 示例

```bash
media-pause 45m                # 45 分钟后暂停 Chrome 媒体
media-pause --now              # 立即暂停
media-pause -r                 # 立即恢复
media-pause -r 10s             # 恢复播放 10 秒后再暂停
media-pause -b brave 30m       # 30 分钟后暂停 Brave
media-pause -b chrome,brave 1h # 同时暂停 Chrome 和 Brave
media-pause -b all 1h          # 暂停所有已安装浏览器
media-pause status             # 查看计时器进度
```

### CDP 优先（可选）

让 Chrome 以调试端口运行，暂停/恢复将优先走 CDP 通道（无需 Apple Events 权限）：

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222
```

## 测试

```bash
bash scripts/verify.sh        # 编译测试（debug+release）+ 单元测试 + 冒烟
swift run media-pause-tests   # 仅单元测试（88 个）
python3 scripts/mutate.py     # 变异测试（一轮约 1-2 分钟，杀灭率 92%+）
```

> 说明：本机只有 Command Line Tools（无 Xcode）时没有 XCTest，因此单元测试使用自带轻量断言框架（`Tests/MediaPauseCoreTests/TestKit.swift`），变异测试为自定义 runner（`scripts/mutate.py`）。

## 架构

```
Sources/MediaPauseCore/   核心逻辑（纯逻辑可测）
  Duration.swift          时长解析/格式化
  Arguments.swift         CLI 参数解析 → Command
  Browser.swift           浏览器注册表
  MediaJS.swift           JS 表达式与计数器解析
  Channels.swift          通道协议 + MediaEngine 降级引擎
  AppleScriptChannel.swift JS 注入/静音通道（Process 可注入）
  MediaKeyChannel.swift   媒体键 + MediaRemote 通道
  CDPChannel.swift        CDP 协议助手 + 通道（Transport 可注入）
  CountdownTimer.swift    可暂停倒计时状态机（Clock 可注入）
  IPC.swift               计时器状态文件编解码
  Setup.swift             启用 Apple Events JS（Preferences 编辑）
  Report.swift            结果格式化
Sources/media-pause/      可执行层（TUI、通道工厂、编排）
Tests/MediaPauseCoreTests/ 单元测试 + 轻量断言框架
scripts/                   verify.sh（编译测试） / mutate.py（变异测试）
```

进程间通信：`/tmp/media-pause.pid`、`/tmp/media-pause.status`（格式见 `IPC.swift`），菜单栏与 Raycast 读取同一格式。

## 变更记录（v4.0 重构）

- 单文件 1381 行 → SwiftPM 多模块分层
- 新增 CDP 通道（Chrome DevTools Protocol）
- 新增 `status` / `stop` / `setup` 子命令
- 移除 SIGSTOP 冻结（损坏媒体管线）、`--profile` / `--list-profiles`
- 新增单元测试（88 个）、编译测试、变异测试
- 保留 IPC 文件格式，菜单栏 / Raycast 兼容

## 许可

MIT
