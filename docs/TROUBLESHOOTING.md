# 故障对照与处理

## 任务栏有图标，但没有窗口

先区分真正的最小化/屏幕外窗口，与 WSLg 根本没有把像素传到 Windows。恢复前台和移动窗口只解决前一类。

```bash
awk '/RDP backend: use_gfxredir =/{last=$0} END {print last}' /mnt/wslg/weston.log
grep 'rdp_allocate_shared_memory: Failed' /mnt/wslg/weston.log | tail -3
```

如果最新是 `= 0`，同时有共享内存 I/O 错误和 `[WARN:COPY MODE]`，保存图形应用中的工作后，用启动器的 `-RepairGraphics`，或在 Windows 执行：

```powershell
wsl -d Ubuntu-24.04 --system --exec pkill -TERM -x weston
```

等待最新记录为 `= 1`，再创建新桌面。重启图形组件会关闭 Linux 图形应用，不能把它当成无副作用的状态查询。

仅在用户发行版中创建 `/mnt/shared_memory` 或挂载 tmpfs，并不意味着修好了系统发行版中的共享内存通道。现场系统发行版已有对应挂载，但分配仍返回 `Input/output error`。不要把不同环境的临时办法不加检查地叠加。

## 看到了桌面，但鼠标或键盘不响应

把画面恢复和输入恢复作为两个独立结果。现场在 Weston 重启后看到了桌面，但用户仍无法操作；之后重新创建桌面会话才恢复。

保存工作，使用 Windows 启动器的 `-RestartSession`。脚本保留了创建窗口前等待两秒以及 Xephyr `-no-host-grab`。这些是兼容措施；目前没有证据能将修复唯一归因于其中一个选项。

不要循环重启整个 WSL，也不要在没有确认的情况下结束用户的无关终端服务。

## 只有空窗口，没有菜单和桌面图标

检查会话日志：

```bash
tail -60 ~/.local/state/wsl-xfce-desktop/session.log
```

如果子进程试图打开 `wayland-0`，而本应使用 Xephyr 的 `:1` 或其他编号，检查 `GDK_BACKEND=x11`、`QT_QPA_PLATFORM=xcb` 和独立的 D-Bus 会话。仅 unset WAYLAND_DISPLAY 不足以强制 GTK 使用 X11。

不要用所有 `Gtk-WARNING` 判断根因；某些 UPower、缩略图或通知服务警告不会阻止基本桌面使用。

## 终端默认到了 /mnt/c 或 /mnt/d

Windows 的启动目录会被 WSL 继承，随后被面板和终端继承。解决方法：桌面会话启动前 `cd "$HOME"`，默认终端入口明确指定 `Path` 和 `--working-directory`。

如果手动编辑面板启动项，可在 Xfce 中右键终端图标，编辑其属性。不要无条件往 `.bashrc` 添加 `cd ~`。不要照搬某台机器的 `launcher-17` 文件夹。

## APT 提示被 unattended-upgrades 占用

**默认行为：等待，不删锁，不自动终止更新。** 安装脚本使用 `DPkg::Lock::Timeout=300`。超过等待时间后，检查：

```bash
systemctl status apt-daily-upgrade.service --no-pager
pgrep -a -x dpkg
ps -eo pid,ppid,etimes,stat,comm
sudo tail -20 /var/log/unattended-upgrades/unattended-upgrades.log
sudo tail -20 /var/log/unattended-upgrades/unattended-upgrades-dpkg.log
```

如果 dpkg 正在解包或配置，等待当前操作完成。不要终止它。

现场自动更新卡在网络下载二十多分钟，直接子进程只有 `/usr/lib/apt/methods/http`，没有 dpkg，更新安装日志为空。处理顺序是：

1. 检查实际进程和程序源码，确认 `unattended-upgrade` 支持 `SIGTERM` 作为正常退出请求。
2. 给准确的更新进程发 `SIGTERM`，没有关闭以后自动更新的计时器。
3. 退出处理被原生网络等待阻塞，又只结束了该进程自己的 HTTP 下载子进程，让等待返回。
4. 日志出现 `SIGTERM received, will stop`，安装锁释放，Chrome 安装继续。

这是一段**受条件约束的现场恢复记录**，不是推荐无条件执行的安装步骤。项目故意不提供自动杀更新进程的命令。现场尝试 SIGINT 没有效果；后来确认该程序显式处理的是 SIGTERM，也说明不能凭记忆猜信号。

## Chrome 已安装，但验证脚本说没窗口

先看真实窗口。Chrome 的 WM_CLASS 可能是 `Google-chrome-stable`，不要只匹配 `Google-chrome`。也不要把一个 10×10 的辅助窗口当作浏览器主窗口。

调试启动时保持 WSL 进程与应用生命周期一致，使用 `wsl-xfce-app`。不要在短命验证脚本中 `nohup ... &` 后立即退出，再把应用随后的退出误判成纯 GPU 故障。

Chrome 使用普通用户和官方沙箱。若 GPU/zygote 报错，先检查进程生命周期、显示环境和可见画面。不要以 `--no-sandbox` 为通用修复。

## 中文或 WSL 输出乱码

Windows 的 `wsl --list`、`wsl --version` 输出在某些工具管道中可能被当成错误编码。现场设置下面变量后可正常读取：

```powershell
$env:WSL_UTF8 = '1'
```

更旧的 WSL 如果不支持这个变量，需按实际输出编码读取，不能把乱码当成发行版不存在。

Windows PowerShell 5.1 对无 BOM 的非 ASCII 脚本可能按本地代码页解释。本仓库的 PowerShell 源码使用 ASCII；中文放在 UTF-8 文档中。自己添加中文脚本消息时，检查 5.1 的实际读取结果。
