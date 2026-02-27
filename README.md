# macpower 完整解决方案（M 系列 / 夜间不断线 / 省电）

这个包把"**极致省电但不断线**"方案整理成一个可安装的完整体，包括：
- 系统级命令：`macpower`（v1.0.0）
- 智能自动化包装：`macpower-auto`（v3.3.0）
- launchd 定时任务：23:00 自动开启、08:00 自动恢复（带环境判断与护栏）
- 安装/卸载脚本
- sudoers 模板（让自动化可在无交互环境修改 pmset）

> 目标：夜间需要跑任务时，**不进入系统 sleep 导致网络断开**；同时尽量省电（屏幕 1 分钟灭、磁盘 5 分钟休眠）。

---

## 一、你将得到什么

### 1) `macpower`（系统级 CLI）
- `macpower on`：开启夜跑策略（默认只影响 **插电 AC**）
- `macpower off`：恢复"类默认"电源策略（AC）
- `macpower save`：备份当前 `pmset -g custom` 到 `~/.macpower.pmset.bak`
- `macpower restore`：从备份回滚（推荐优先用这个）
- `macpower status`：查看当前状态
- `macpower version`：查看版本号

**夜跑策略（AC）参数：**
- `sleep 0` `standby 0` `autopoweroff 0` `powernap 0`
- `displaysleep 1` `disksleep 5`
- `tcpkeepalive 1`

**备份恢复安全机制：**
- `macpower restore` 解析备份文件时会校验每个 key 是否属于已知 pmset 参数白名单
- value 必须是整数或路径格式，否则跳过
- 未知 key 和异常格式行会被安全跳过并输出提示

### 2) `macpower-auto`（智能判断）
- 23:00 触发时，会先检查：
  - 是否插电（AC）。不插电直接 SKIP（你说你多数晚上不插电，这就是预期行为）
  - Wi-Fi 是否连接到某个 SSID。未连接则 SKIP
  - 盖子是否合上：默认 SKIP（你说几乎不合盖跑）
  - 如果你手动开启了 night 策略，它会识别"已开启"，不会重复设置，但会确保早上会恢复
- morning 恢复时：只有在 night 真开启/标记过才会恢复，避免误改。
- 内置日志轮转：日志文件超过 512KB 自动截断保留最近内容

### 3) LaunchAgents
- `com.user.macpower.night`：每天 23:00 运行 `macpower-auto night`
- `com.user.macpower.morning`：每天 08:00 运行 `macpower-auto morning`
- 日志：
  - `~/Library/Logs/macpower/night.log` / `~/Library/Logs/macpower/night.err`
  - `~/Library/Logs/macpower/morning.log` / `~/Library/Logs/macpower/morning.err`

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
- 智能判断目标目录权限，仅在需要时使用 sudo
- 创建日志目录 `~/Library/Logs/macpower/`
- 把两个 plist 复制到 `~/Library/LaunchAgents` 并自动 load（优先使用 `launchctl bootstrap`，兼容旧版 `launchctl load`）
- 可选：帮你安装 sudoers（推荐安装）

> 安装完成后建议做一次备份：
```bash
macpower save
```

### 方式 B：手动安装
1. 复制脚本到 PATH 目录，并 `chmod +x`
2. 复制 plist 到 `~/Library/LaunchAgents`
   - 需要将 plist 中的 `__HOME__` 替换为你的实际 HOME 路径
   - 需要将 `/opt/homebrew/bin` 替换为你的实际安装路径（如果不同）
3. 创建日志目录：`mkdir -p ~/Library/Logs/macpower`
4. 加载 plist：
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.macpower.morning.plist
```

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

### 查看版本号
```bash
macpower version
macpower-auto version
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
因为你多数晚上不插电：`macpower-auto night` 会检测到非 AC -> SKIP（这是你要求的"保守逻辑"）。

### 2) 我手动开了 `macpower on`，结果第二天忘了关怎么办？
23:00 的任务会检测到"night policy already active"，并写入标记文件，让 08:00 自动 restore（除非你那晚不插电/没跑到）。

### 3) 查看日志
```bash
tail -n 200 ~/Library/Logs/macpower/night.log ~/Library/Logs/macpower/night.err
tail -n 200 ~/Library/Logs/macpower/morning.log ~/Library/Logs/macpower/morning.err
```

### 4) 想改时间（比如 22:30 / 7:30）
编辑 `~/Library/LaunchAgents/*.plist` 的 `StartCalendarInterval`，然后重新加载：
```bash
# 卸载旧的
launchctl bootout gui/$(id -u)/com.user.macpower.night 2>/dev/null || \
  launchctl unload ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl bootout gui/$(id -u)/com.user.macpower.morning 2>/dev/null || \
  launchctl unload ~/Library/LaunchAgents/com.user.macpower.morning.plist

# 加载新的
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.macpower.night.plist 2>/dev/null || \
  launchctl load ~/Library/LaunchAgents/com.user.macpower.night.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.macpower.morning.plist 2>/dev/null || \
  launchctl load ~/Library/LaunchAgents/com.user.macpower.morning.plist
```

### 5) 如果你确实想偶尔合盖跑（可选）
你几乎不需要，但脚本保留了"显式合盖跑"开关：
```bash
macpower-auto night --clamshell
```
它会要求检测到外接显示器/ dummy HDMI，否则拒绝（避免你误以为合盖能跑而实际睡眠断网）。

---

## 六、卸载

```bash
bash scripts/uninstall.sh
```

卸载脚本会：
- 卸载并删除 LaunchAgents
- 删除 `macpower` / `macpower-auto` 脚本
- 自动删除 night 标记文件
- 提示是否删除 pmset 备份文件（`~/.macpower.pmset.bak`）
- 提示是否删除日志目录（`~/Library/Logs/macpower/`）
- 自动清理旧版 `/tmp/macpower_*.log` 日志文件（如有）

可选：删除 sudoers
```bash
sudo rm -f /etc/sudoers.d/macpower
```

---

## 七、安全说明

- 本方案通过 sudoers 放行了 `pmset` 免密执行（只放行一个系统命令）。
- 这是为了让 launchd 自动化在无交互环境下生效。
- 如果你不希望免密，请不要装 sudoers；但自动化将无法修改电源策略（只会在日志里失败）。
- `macpower restore` 从备份恢复时会对每个参数进行白名单校验，防止异常数据被写入 pmset。
- 日志存放在 `~/Library/Logs/macpower/`（用户目录），避免 `/tmp` 的安全和持久性问题。
