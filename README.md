# macpower 完整解决方案（M 系列 / 夜间不断线 / 省电）

这个包把我们讨论过的“**极致省电但不断线**”方案整理成一个可安装的完整体，包括：
- 系统级命令：`macpower`
- 智能自动化包装：`macpower-auto`（v3.3）
- launchd 定时任务：23:00 自动开启、08:00 自动恢复（带环境判断与护栏）
- 安装/卸载脚本
- sudoers 模板（让自动化可在无交互环境修改 pmset）

> 目标：夜间需要跑任务时，**不进入系统 sleep 导致网络断开**；同时尽量省电（屏幕 1 分钟灭、磁盘 5 分钟休眠）。

---

## 一、你将得到什么

### 1) `macpower`（系统级 CLI）
- `macpower on`：开启夜跑策略（默认只影响 **插电 AC**）
- `macpower off`：恢复“类默认”电源策略（AC）
- `macpower save`：备份当前 `pmset -g custom` 到 `~/.macpower.pmset.bak`
- `macpower restore`：从备份回滚（推荐优先用这个）
- `macpower status`：查看当前状态

**夜跑策略（AC）参数：**
- `sleep 0` `standby 0` `autopoweroff 0` `powernap 0`
- `displaysleep 1` `disksleep 5`
- `tcpkeepalive 1`

### 2) `macpower-auto`（智能判断）
- 23:00 触发时，会先检查：
  - 是否插电（AC）。不插电直接 SKIP（你说你多数晚上不插电，这就是预期行为）
  - Wi‑Fi 是否连接到某个 SSID。未连接则 SKIP
  - 盖子是否合上：默认 SKIP（你说几乎不合盖跑）
  - 如果你手动开启了 night 策略，它会识别“已开启”，不会重复设置，但会确保早上会恢复
- morning 恢复时：只有在 night 真开启/标记过才会恢复，避免误改。

### 3) LaunchAgents
- `com.user.macpower.night`：每天 23:00 运行 `macpower-auto night`
- `com.user.macpower.morning`：每天 08:00 运行 `macpower-auto morning`
- 日志：
  - `/tmp/macpower_night.log` `/tmp/macpower_night.err`
  - `/tmp/macpower_morning.log` `/tmp/macpower_morning.err`

---

## 二、安装

### 方式 A：一键安装（推荐）
在解压目录里运行：

```bash
bash scripts/install.sh
```

安装脚本会：
- 把 `macpower` / `macpower-auto` 复制到：
  - 优先 `/opt/homebrew/bin`（多数 M 系列机器）
  - 否则 `/usr/local/bin`
- 把两个 plist 复制到 `~/Library/LaunchAgents` 并自动 load
- 可选：帮你安装 sudoers（推荐安装）

> 安装完成后建议做一次备份：
```bash
macpower save
```

### 方式 B：手动安装
1. 复制脚本到 PATH 目录，并 `chmod +x`
2. 复制 plist 到 `~/Library/LaunchAgents`
3. `launchctl load ...`

---

## 三、sudoers（自动化必需）

`pmset` 修改系统电源策略需要 root 权限。  
launchd 到点执行没有交互终端，不能输入 sudo 密码，所以需要放行：

- 允许你对 `/usr/bin/pmset` 使用免密 sudo

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
macpower on
macpower status
macpower restore   # 推荐回滚到你自己的备份
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

### 1) 为什么晚上经常“什么都没发生”？
因为你多数晚上不插电：`macpower-auto night` 会检测到非 AC -> SKIP（这是你要求的“保守逻辑”）。

### 2) 我手动开了 `macpower on`，结果第二天忘了关怎么办？
23:00 的任务会检测到“night policy already active”，并写入标记文件，让 08:00 自动 restore（除非你那晚不插电/没跑到）。

### 3) 查看日志
```bash
tail -n 200 /tmp/macpower_night.log /tmp/macpower_night.err
tail -n 200 /tmp/macpower_morning.log /tmp/macpower_morning.err
```

### 4) 想改时间（比如 22:30 / 7:30）
编辑 `~/Library/LaunchAgents/*.plist` 的 `StartCalendarInterval`，然后：
```bash
launchctl unload ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl unload ~/Library/LaunchAgents/com.user.macpower.morning.plist
launchctl load ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl load ~/Library/LaunchAgents/com.user.macpower.morning.plist
```

### 5) 如果你确实想偶尔合盖跑（可选）
你几乎不需要，但脚本保留了“显式合盖跑”开关：
```bash
macpower-auto night --clamshell
```
它会要求检测到外接显示器/ dummy HDMI，否则拒绝（避免你误以为合盖能跑而实际睡眠断网）。

---

## 六、卸载

```bash
bash scripts/uninstall.sh
```

可选：删除 sudoers
```bash
sudo rm -f /etc/sudoers.d/macpower
```

---

## 七、安全说明

- 本方案通过 sudoers 放行了 `pmset` 免密执行（只放行一个系统命令）。
- 这是为了让 launchd 自动化在无交互环境下生效。
- 如果你不希望免密，请不要装 sudoers；但自动化将无法修改电源策略（只会在日志里失败）。

