# WSL Ubuntu Xfce Guide

把 **Ubuntu 24.04 + Xfce 完整桌面 + Chrome** 安装到已有的 WSL 2 中，并记录一次真实安装中遇到的显示、输入、目录和安装阻塞问题。中文文档优先，适合用户操作，也适合交给其他 AI 接着处理。

> 给 AI：先读 [AGENTS.md](AGENTS.md) 和 [AI 操作手册](docs/AI_RUNBOOK.md)。`pgrep`、窗口标题、`SetForegroundWindow=True` 都不能单独证明桌面可用。必须确认 Windows 实际画面与鼠标键盘输入。

## 方案

```text
Windows 快捷方式
  → PowerShell 检查 WSLg / 恢复已有窗口
  → 已有 Ubuntu 的普通用户
  → Xephyr 独立 X11 窗口
  → 独立 D-Bus 会话中的 Xfce 桌面
  → 终端、文件管理器、Chrome
```

使用 WSL 自带的图形支持，不需要安装远程桌面服务器或设置额外的桌面登录密码。Xephyr 只使用本地连接，启用独立的 Xauthority cookie，不使用 `-ac`。

## 适用范围与验证边界

- Windows 上已有 WSL 2、WSLg 和 Ubuntu 24.04。
- 有一个现成的普通 Linux 用户；包安装由 WSL 的 root 用户执行，桌面和 Chrome 以普通用户运行。
- Chrome 官方 Linux `.deb` 仅适用于 **amd64 / x86_64**，不适用于 ARM64。
- 真实会话已验证桌面显示、鼠标操作、中文界面、终端家目录、Chrome 安装与窗口显示。
- 本仓库在现场脚本基础上做了参数化；完整安装程序没有在一台全新 Windows 机器上重新跑过。自动检查覆盖脚本语法、启动参数、配置保留和进程停止保护。详见 [验证记录](docs/VALIDATION.md)。

项目不会创建、重装或移动你的 Linux 发行版，不会自动修改 `/etc/wsl.conf` 或 `.wslconfig`，也不会替你终止卡住的系统更新。

## 快速开始

下载并解压项目。在 **你平时使用 WSL 的 Windows 账户** 中打开 PowerShell，进入项目文件夹。

先检查目标，发行版名称以 `wsl --list --verbose` 为准：

```powershell
.\windows\Install-Desktop.ps1 -Distro Ubuntu-24.04 -CheckOnly
```

安装桌面及 Chrome：

```powershell
.\windows\Install-Desktop.ps1 -Distro Ubuntu-24.04 -WithChrome
```

如果默认 Linux 用户是 root，指定现有普通用户：

```powershell
.\windows\Install-Desktop.ps1 -Distro Ubuntu-24.04 -LinuxUser yourname -WithChrome
```

如果 PowerShell 提示脚本执行策略限制，可只对这一次进程放行，不修改整台电脑的策略：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\Install-Desktop.ps1 -Distro Ubuntu-24.04 -WithChrome
```

完成后，双击 Windows 桌面的 **Ubuntu Desktop - Ubuntu-24.04**。首次启动需要几秒钟。点击 Xfce 的应用菜单，确认能展开，再打开终端确认提示符在 `~`。

已经安装所有组件，只想重新部署脚本及入口时，可用 `-ConfigureOnly`。这会更新本项目管理的启动脚本和默认入口；先保存图形应用中的工作。

## 日常使用

| 操作 | 方法 |
|---|---|
| 打开完整桌面 | 双击 Windows 桌面的 Ubuntu Desktop 快捷方式 |
| 恢复已打开的桌面 | 再次双击快捷方式 |
| 终端默认位置 | Linux 家目录 `$HOME`，通常显示为 `~` |
| 打开浏览器 | 底部栏原来的浏览器入口；已有默认入口会更新为 Chrome 图标 |
| 查看 Linux 诊断 | 在 Ubuntu 中运行 `~/.local/bin/wsl-xfce-diagnose` |
| 查看启动日志 | `~/.local/state/wsl-xfce-desktop/session.log` |
| 关闭桌面 | 关闭桌面窗口；这会结束该桌面会话中的图形应用 |

Windows 启动文件复制到 `%LOCALAPPDATA%\WSL-Xfce\<发行版名>`，Linux 启动文件安装到 `~/.local/bin` 和 `~/.local/share/wsl-xfce`。安装后移动下载的项目文件夹不会破坏快捷方式。

## 遇到任务栏有图标、窗口却看不见

检查最新一条图形模式记录，而不是看到任意一条 `0` 就判断失败：

```bash
awk '/RDP backend: use_gfxredir =/{last=$0} END {print last}' /mnt/wslg/weston.log
```

现场故障是 `use_gfxredir = 0`、共享内存分配 `Input/output error`，且窗口标题出现 `[WARN:COPY MODE]`。重启 WSLg 的 Weston 后变成 `1`，Windows 画面才真正出现。

Windows 启动器会检测该情况，并在重启图形组件前说明会关闭 Linux 图形应用。已经明确准备好重启图形组件，可在 PowerShell 中运行：

```powershell
& "$env:LOCALAPPDATA\WSL-Xfce\Ubuntu-24.04\Launch-Desktop.ps1" -RepairGraphics
```

如果已经有画面但鼠标键盘不响应，现场是在图形组件恢复后，**重新创建桌面会话** 才恢复输入。保存工作后运行：

```powershell
& "$env:LOCALAPPDATA\WSL-Xfce\Ubuntu-24.04\Launch-Desktop.ps1" -RestartSession
```

两秒等待和 `-no-host-grab` 是现场保留下来的兼容措施，不代表已证明它们中的某一个是输入故障的唯一原因。

## 文档与检查

- [AI 操作手册](docs/AI_RUNBOOK.md)：下一位 AI 应按什么顺序检查，哪些结论不能跳步。
- [故障对照与处理](docs/TROUBLESHOOTING.md)：显示、输入、安装锁、Chrome 与编码问题。
- [真实会话复盘](docs/SESSION_REPORT.md)：失败尝试、有效修复、用户确认和证据边界。
- [验证记录](docs/VALIDATION.md)：已经测过什么，还有什么没有测过。

Linux / WSL 中运行：

```bash
bash tests/check-shell.sh
python3 -m unittest discover -s tests -v
```

Windows PowerShell 中运行：

```powershell
.\tests\Test-Windows.ps1
```

仓库不包含聊天截图、用户文件、原始环境日志、安装包或 Chrome 用户配置。MIT 许可证只涵盖本项目代码和文档，不涵盖 Google Chrome 本身。
