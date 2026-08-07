# media-pause 重构需求文档

> 状态：已锁定（2026-08-07）
> 目标：**控制 Chrome 音视频的定时暂停 / 恢复**，并在完全重构的同时保证可测试性。

## 1. 现有功能梳理

### 1.1 现状盘点

| 模块 | 现状 | 问题 |
|------|------|------|
| 核心 CLI | 单文件 `main.swift`（1381 行，v3.1.3） | 单体巨型文件；手写参数解析；逻辑与 UI 混杂；无任何测试 |
| 暂停/恢复通道 | AppleScript JS 注入 → CGEvent 媒体键 → MediaRemote → (已移除 SIGSTOP) | 依赖隐藏权限"允许 Apple Events 中的 JavaScript"；JS 字符串拼接脆弱；文档与实际代码漂移（CLAUDE.md 描述 v3.1.2，实际已 v3.1.3+） |
| 死代码/遗留 | SIGSTOP freeze helpers、automation 实例特判、`--profile`/`--list-profiles` | 已从自动链路移除但仍保留，增加维护负担 |
| 菜单栏 | SwiftUI `NSStatusItem` 倒计时，读 `/tmp` IPC | 功能正常，依赖旧 IPC 格式 |
| Raycast | 7 个薄脚本直接调 `media-pause` | `timer-status`/`timer-stop` 用 `pgrep`/`pkill` 硬编码进程名，脆弱 |
| Homebrew | 单文件 `swiftc` 编译 | 需随工程结构调整 |
| 文档 | README / CLAUDE.md | 与代码漂移，需要重写 |

### 1.2 现状核心机制（重构后保留的能力）

- **AppleScript JS 注入**：`tell application "Google Chrome" … execute t javascript …`，逐标签页暂停/恢复 `<video>/<audio>` 元素。需要权限 `View → Developer → Allow JavaScript from Apple Events`。
- **系统媒体键**：`CGEvent` 投递播放/暂停键到 Chrome PID；`MediaRemote` 私有无框架发送系统级切换。
- **计时器**：终端倒计时 TUI，支持 Space 暂停/恢复、Ctrl+C 取消；写 `/tmp/media-pause.pid` 与 `/tmp/media-pause.status` 供菜单栏/Raycast 读取。
- **时长解析**：`3600` / `1h` / `30m` / `1h30m` / `2h15m30s`。

## 2. 需求锁定

### R1 定时暂停
输入时长（如 `30m`）后倒计时，到时**暂停 Chrome 所有标签页中的音视频**。

### R2 定时/即时恢复
- `media-pause -r`：立即恢复播放；
- `media-pause -r 10s`：恢复播放 10 秒后再暂停；
- `media-pause --now -r`：立即恢复（等价于 `-r`）。

### R3 即时操作
`media-pause --now` 不等待倒计时立即暂停。

### R4 Chrome 优先、多浏览器兼容
默认目标为 Chrome；保留浏览器注册表（chrome/brave/edge/arc/chromium/opera/vivaldi + `all`），核心链路针对 Chrome 优化。

### R5 多通道降级引擎
按优先级尝试通道，**诚实报告**每个通道的结果：
1. **CDP**（Chrome DevTools Protocol）——若检测到远程调试端口则优先（处理 Web Audio、无需 Apple Events 权限）；
2. **AppleScript JS**——逐标签页暂停/恢复媒体元素（需权限，工具可自动修复 `setup`）；
3. **媒体键**——CGEvent 投递到实例 PID；
4. **MediaRemote 系统切换**——存在 Now Playing 会话时兜底。

> 决策记录：SIGSTOP 冻结渲染进程**不再进入自动链路**（会损坏 Chrome 媒体管线），相关代码整体删除；`--profile`/`--list-profiles` 移除（AppleScript 通道遍历全部窗口，无需指定 profile）。

### R6 计时器管理
- 同一时间只允许一个计时器；
- `media-pause status` / `media-pause stop` 子命令；
- 终端内 Space 暂停/恢复计时器与媒体、Ctrl+C 取消；
- IPC 格式保持稳定，菜单栏/Raycast 可读。

### R7 集成保持
菜单栏倒计时、Raycast 命令、Homebrew 公式随重构同步更新。

### R8 可测试性
- 纯逻辑（时长解析、参数解析、IPC 编解码、JS 表达式、CDP 消息、通道降级、计时器状态机）全部可单元测试；
- 通道/引擎通过协议注入 fake，不依赖真实 Chrome；
- 提供编译测试（`swift build` + `swift test` 构建成功）与变异测试（muter）。

## 3. Scenario Outline

### S1 定时暂停（核心）
```
Given 用户运行 `media-pause 45m`
When  倒计时 45 分钟后到达
Then  暂停 Chrome 所有标签页中的音视频，输出结果报告
```

### S2 即时暂停
```
Given 用户运行 `media-pause --now`
When  立即执行
Then  暂停 Chrome 全部音视频并报告受影响元素数
```

### S3 定时恢复
```
Given 用户运行 `media-pause -r 10s`
When  立即恢复播放
Then  播放 10 秒后自动再次暂停
```

### S4 立即恢复
```
Given 用户运行 `media-pause -r`（或 `--now -r`）
When  立即执行
Then  恢复 Chrome 全部已暂停的音视频
```

### S5 多浏览器
```
Given 用户运行 `media-pause -b chrome,brave 30m` 或 `-b all 30m`
When  倒计时结束
Then  依次对每个浏览器实例执行通道引擎，输出逐浏览器结果
```

### S6 通道降级
```
Given Chrome 的 Apple Events JS 权限未开启、且无 CDP 端口
When  执行暂停
Then  引擎跳过 JS 通道 → 尝试媒体键 → 报告"未能暂停：无媒体元素且无 Now Playing 会话"，并提示 setup
```

### S7 CDP 优先
```
Given Chrome 以 --remote-debugging-port 运行
When  执行暂停
Then  引擎优先走 CDP 通道（Runtime.evaluate），报告成功
```

### S8 计时器暂停/恢复/取消
```
Given 倒计时运行中
When  用户按 Space / Ctrl+C
Then  Space：计时器与媒体同步暂停/恢复；Ctrl+C：取消并清理 IPC 文件
```

### S9 状态与停止
```
Given 倒计时运行中
When  用户运行 `media-pause status` / `media-pause stop`
Then  status 显示剩余/已用/模式；stop 终止计时器并清理 IPC
```

### S10 菜单栏与 Raycast
```
Given 倒计时运行中
When  用户查看菜单栏或 Raycast Timer Status
Then  显示一致的时间/模式/进度，可停止
```

### S11 权限修复
```
Given Chrome 未开启 "Allow JavaScript from Apple Events"
When  用户运行 `media-pause setup`
Then  自动改写 Chrome Preferences 并尝试菜单点击实时生效
```

### S12 测试质量
```
Given 代码仓库完成重构
When  运行 swift test / swift build / muter
Then  单元测试全部通过；编译成功；变异测试杀灭率达到可接受阈值
```
