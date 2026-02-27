# macpower 完整解决方案（M 系列 / 夜间不断线 / 省电）

这个包把"**极致省电但不断线**"方案整理成一个可安装的完整体，包括：
- 系统级命令：`macpower`
- 智能自动化包装：`macpower-auto`（v3.4）
- launchd 定时任务：23:00 自动开启、08:00 自动恢复（带环境判断与护栏）
- 安装/卸载脚本
- sudoers 模板（让自动化可在无交互环境修改 pmset）

> 目标：夜间需要跑任务时，**不进入系统 sleep 导致网络断开**；同时尽量省电（屏幕 1 分钟灭、磁盘 5 分钟休眠）。

---

## 一、你将得到什么

### 1) `macpower`（系统级 CLI）

| 命令 | 说明 |
|------|------|
| `macpower on` | 开启低功耗保活模式（默认只影响 **插电 AC**），网络未连接时自动 SKIP |
| `macpower on --force` | 开启低功耗保活模式，跳过网络检测 |
| `macpower off` | 应用保守预设（**非出厂默认**，详见说明） |
| `macpower save` | 备份当前 `pmset -g custom` 到 `~/.macpower.pmset.bak`（权限 600） |
| `macpower restore` | 从备份回滚（推荐优先用这个） |
| `macpower status` | 查看当前状态（含中文模式说明） |

**低功耗保活模式（AC）参数：**
- `sleep 0`、`standby 0`、`autopoweroff 0`、`powernap 0`
- `displaysleep 1`、`disksleep 5`
- `tcpkeepalive 1`

> **关于 disksleep 5**：磁盘休眠只影响存储硬件的省电状态，**不会中断正在运行的程序或网络任务**。运行中的进程和网络连接都在内存里，与磁盘无关。如需访问磁盘（如写日志），macOS 会在毫秒级内自动唤醒磁盘，进程不会失败。

> **关于 `macpower off`**：此命令应用一组保守的电源预设值（sleep=10, displaysleep=10 等），**并非 macOS 出厂默认值**（出厂值因机型而异）。如需恢复到你自己的原始设置，请使用 `macpower restore`（前提是先执行过 `macpower save`）。

**`macpower status` 输出说明：**

`status` 命令会在原始 pmset 参数上方，自动显示一段**中文模式说明**，直接告诉你：
- 当前处于哪个模式（低功耗保活 / 非保活）
- 系统休眠与屏幕熄灭的实际时间
- **能否离开电脑跑长期任务（YES / NO）**

示例（低功耗保活已开启）：
```
┌─ 📋 电源模式说明 ─────────────────────────────────────┐
│
│  当前模式：🌙 极致省电长期任务模式（低功耗保活已开启）
│
│  关键特性：
│    • 系统永不休眠（sleep=0）：网络连接始终保活
│    • 快速屏幕熄灭（1分钟）：最小化功耗
│    • 磁盘快速休眠（5分钟）：节省磁盘电能
│    • TCP保活已启用（tcpkeepalive=1）
│
│  📌 长期任务支持：✅ YES
│     • 24小时不间断运行：✓
│     • Wi-Fi 保持连接：✓
│     • 网络通信稳定：✓
│     • 离开前无需干预：✓
│
│  电源来源：Now drawing from 'AC Power'
│
└──────────────────────────────────────────────────────┘
```

### 2) `macpower-auto`（智能判断）

- **23:00 触发**时，会先检查：
  - 是否插电（AC）。不插电直接 SKIP
  - Wi‑Fi 是否连接到某个 SSID（使用 `ipconfig getsummary`，兼容 macOS Sonoma/Sequoia）。未连接则 SKIP
  - 盖子是否合上：默认 SKIP
  - 是否已是低功耗保活模式：若已开启（包括手动 `macpower on`），**识别后跳过，只补写标记文件确保早上会恢复**
  - 若 `macpower on` 执行失败（如 sudo 权限问题），**不写标记文件**，避免早上误恢复
- **morning 恢复**时：
  - 只有在标记文件存在时才会恢复，避免误改
  - **恢复失败时仍会清除标记文件**，防止每天 08:00 无限重试

### 3) LaunchAgents

- `com.user.macpower.night`：每天 23:00 运行 `macpower-auto night`
- `com.user.macpower.morning`：每天 08:00 运行 `macpower-auto morning`
- 日志（安装后自动配置到持久化目录）：
  - `~/Library/Logs/macpower/night.log` / `night.err`
  - `~/Library/Logs/macpower/morning.log` / `morning.err`

---

## 二、安装

### 方式 A：一键安装（推荐）

在项目目录里运行：

```bash
bash scripts/install.sh
```

安装脚本会：
- 把 `macpower` / `macpower-auto` 复制到：
  - 优先 `/opt/homebrew/bin`（多数 M 系列机器）
  - 否则 `/usr/local/bin`
- 把两个 plist 复制到 `~/Library/LaunchAgents`，使用 `launchctl bootstrap` 加载（兼容 macOS Ventura/Sonoma/Sequoia）
- 自动创建日志目录 `~/Library/Logs/macpower/`
- 可选：帮你安装 sudoers（推荐安装）

> 安装完成后建议做一次备份：
```bash
macpower save
```

### 方式 B：手动安装
1. 复制脚本到 PATH 目录，并 `chmod +x`
2. 复制 plist 到 `~/Library/LaunchAgents`
3. `launchctl bootstrap gui/$(id -u) <plist路径>`

---

## 三、sudoers（自动化必需）

`pmset` 修改系统电源策略需要 root 权限。
launchd 到点执行没有交互终端，不能输入 sudo 密码，所以需要放行：

- 允许你对 `/usr/bin/pmset` 使用免密 sudo

> **安全提示**：此规则允许该用户以 root 身份免密执行 pmset 的**所有子命令**（包括 `pmset schedule shutdown`）。sudoers 无法限制 pmset 的具体参数。请确认你信任该账户。

模板在：`sudoers/macpower`

安装方式（推荐用 visudo）：

```bash
sudo visudo -f /etc/sudoers.d/macpower
```

把模板内容粘贴进去，并把 `YOUR_USERNAME` 改成 `whoami` 的结果。

验证：

```bash
sudo /usr/sbin/visudo -cf /etc/sudoers.d/macpower
```

---

## 四、日常使用

### 手动开启/恢复
```bash
macpower on          # 开启低功耗保活模式（需有网络连接）
macpower on --force  # 开启低功耗保活模式（跳过网络检测）
macpower status      # 查看当前模式和长期任务支持状态
macpower restore     # 推荐：从备份回滚到原始设置
macpower off         # 应用保守预设（非出厂默认）
```

### 查看自动化状态
```bash
macpower-auto status
launchctl list | grep macpower
```

### 手动触发一次夜间逻辑（不用等 23:00）
```bash
macpower-auto night
```

### 手动触发一次早上恢复（不用等 08:00）
```bash
macpower-auto morning
```

---

## 五、维护与排障

### 1) 为什么晚上经常"什么都没发生"？

两种可能：
- **不插电**：`macpower-auto night` 检测到非 AC → SKIP（保守逻辑，预期行为）
- **Wi-Fi 未连接**：未连接网络 → SKIP

查看日志确认原因：
```bash
tail -n 50 ~/Library/Logs/macpower/night.log
```

### 2) 我手动开了 `macpower on`，晚上 23:00 会重复执行吗？

不会重复 apply。23:00 的任务会检测到低功耗保活模式已激活，直接跳过并补写标记文件，确保 08:00 自动 restore。完整流程：

```
手动 macpower on → 低功耗保活已开启
23:00 → 检测到已激活 → 静默跳过，补写 mark file
08:00 → 发现 mark file → macpower restore → 清除 mark file
```

### 3) `macpower on` 提示 SKIP: No network connection 怎么办？

说明当前 Wi-Fi 和以太网都未连接。连接网络后重试，或强制执行：
```bash
macpower on --force
```

### 4) 磁盘休眠（disksleep 5）会影响运行中的程序吗？

**不影响。** 磁盘休眠只是让存储硬件进入省电状态，CPU、内存、网络全部保持活跃。运行中的程序和网络连接不依赖磁盘。如果程序需要写磁盘（写日志等），macOS 会在毫秒级内自动唤醒磁盘，进程透明等待，不会报错或中断。

### 5) 查看日志
```bash
tail -n 200 ~/Library/Logs/macpower/night.log ~/Library/Logs/macpower/night.err
tail -n 200 ~/Library/Logs/macpower/morning.log ~/Library/Logs/macpower/morning.err
```

### 6) 想改时间（比如 22:30 / 7:30）
编辑 `~/Library/LaunchAgents/*.plist` 的 `StartCalendarInterval`，然后重新加载：
```bash
DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN" ~/Library/LaunchAgents/com.user.macpower.night.plist 2>/dev/null || true
launchctl bootout "$DOMAIN" ~/Library/LaunchAgents/com.user.macpower.morning.plist 2>/dev/null || true
launchctl bootstrap "$DOMAIN" ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl bootstrap "$DOMAIN" ~/Library/LaunchAgents/com.user.macpower.morning.plist
```

### 7) 如果你确实想偶尔合盖跑（可选）
脚本保留了"显式合盖跑"开关：
```bash
macpower-auto night --clamshell
```
它会要求检测到外接显示器（HDMI / DisplayPort / Thunderbolt / USB-C），否则拒绝（避免合盖实际睡眠断网）。

### 8) 恢复失败怎么办？

如果 `macpower restore` 或 `macpower-auto morning` 报 WARN 错误：
- 某些多词参数（如 `Sleep On Power Button`）在备份解析时可能报 WARN，**不影响核心参数恢复**
- 脚本会继续恢复其他参数，不会因单个失败而中断
- 标记文件会被清除，不会造成次日重复触发
- 运行 `macpower status` 确认关键参数已恢复即可

---

## 六、卸载

```bash
bash scripts/uninstall.sh
```

卸载脚本会：
- 自动检测并恢复活跃的低功耗保活设置
- 清除标记文件
- 卸载 LaunchAgents
- 删除脚本文件

可选：手动删除 sudoers 和日志
```bash
sudo rm -f /etc/sudoers.d/macpower
rm -rf ~/Library/Logs/macpower
```

---

## 七、安全说明

- 本方案通过 sudoers 放行了 `pmset` 免密执行（只放行一个系统命令）。
- **注意**：此规则允许该用户免密执行 pmset 的所有子命令（包括 `pmset schedule shutdown`），因为 sudoers 无法限制 pmset 的具体参数。
- 这是为了让 launchd 自动化在无交互环境下生效。
- 如果你不希望免密，请不要装 sudoers；但自动化将无法修改电源策略（只会在日志里失败）。
- 备份文件权限已限制为 600（仅当前用户可读写）。

---

## 八、错误处理与容错设计

本方案在以下场景中做了容错处理：

| 故障场景 | 处理方式 |
|---------|---------|
| `pmset` 单个参数设置失败（如不支持的参数） | 记录 WARN，继续设置其余参数，不中断 |
| `macpower on` 整体失败（如 sudo 权限问题） | 不写标记文件，早上不会误触恢复 |
| `macpower restore` 恢复失败 | 清除标记文件防止每日无限重试，日志记录警告 |
| Wi-Fi 检测 API 变化（Sonoma/Sequoia） | 已从废弃的 `networksetup` 切换到 `ipconfig getsummary` |
| M 系列不支持 `autopoweroff` | 检测函数中排除该参数，设置函数保留（防御性） |
| 卸载时低功耗保活仍在生效 | 卸载脚本自动检测并恢复默认电源设置 |
