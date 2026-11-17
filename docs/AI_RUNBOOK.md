# 给下一位 AI 的操作手册

## 0. 先理解目标

用户要的是能看见、能操作的完整 Linux 桌面，然后在其中使用终端和 Chrome。本方案是 WSLg + Xephyr + Xfce；不是在 Windows 中安装另一份 Ubuntu，也不是把一批后台进程当成最终交付。

安装前先看现有环境，确认已经得到的授权，不重复询问已经明确的普通安装操作。涉及关闭已有图形应用时，要说明会影响未保存内容。

## 1. 检查执行账户，再检查发行版

Windows PowerShell：

```powershell
whoami
$env:WSL_UTF8 = '1'
wsl --list --verbose
wsl --version
```

**现场第一坑：**执行工具运行在隔离账户下，`wsl --list` 说没有发行版；用户实际 Windows 账户中已有 Ubuntu。`$env:USERPROFILE` 看起来像用户目录，也不意味着 `whoami` 真的是那个用户。先切换到正确的执行上下文，再决定是否需要安装发行版。

不要因此安装第二套 Ubuntu，不要移动现有 VHD，不要注销发行版。

## 2. 确认现有 Linux 用户和显示环境

```powershell
wsl -d Ubuntu-24.04 --exec id
wsl -d Ubuntu-24.04 --exec cat /etc/os-release
wsl -d Ubuntu-24.04 --exec printenv DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR
wsl -d Ubuntu-24.04 --exec cat /etc/wsl.conf
```

Ubuntu-24.04 只是例子，用实际发行版名称替换。通过 `getent passwd <用户名>` 取得家目录，不假定永远是 `/home/ubuntu`。

Windows 到 Linux 的复杂脚本建议保存为 LF 换行的 `.sh` 文件后调用：

```powershell
wsl -d Ubuntu-24.04 --exec bash /mnt/d/path/to/script.sh
```

避免在 PowerShell、WSL 默认 shell、`bash -lc` 之间层层拼接引号和 `$(...)`。现场曾出现命令替换提前执行、路径内残留字面引号。`command` 是 shell 内建命令，不能用 `wsl --exec command -v ...` 直接当可执行文件。

## 3. 安装软件，配置用户

优先使用 `windows/Install-Desktop.ps1`。包安装脚本以 root 运行；用户配置脚本、Xfce 和 Chrome 以普通用户运行。保留现有 `/etc/wsl.conf`，只有确实缺少必要设置时才讨论修改。

APT 可能被自动更新占用。默认等待最多 300 秒，不删除锁文件。查看锁持有者、服务、子进程和更新日志，区分下载、解包和配置阶段。详见故障手册。

Chrome 只从官方 HTTPS 地址取得 `.deb`，检查包名和 amd64 架构，然后交给 APT 解决依赖。下载成功不等于安装成功；安装成功不等于图形窗口已经可用。

## 4. 正确启动 Xfce

必要设置在 `linux/start-xfce-desktop` 中：

- 保留 WSLg 的父显示，Xephyr 使用另一个未占用的显示编号。
- `-nolisten tcp`，独立 Xauthority cookie，不用 `-ac`。
- `dbus-run-session -- startxfce4`，不要覆盖用户已有的全局 D-Bus 环境。
- 清除当前启动进程中的 `WAYLAND_DISPLAY`、旧 `DBUS_SESSION_BUS_ADDRESS` 和 `SESSION_MANAGER`。
- **显式设置 `GDK_BACKEND=x11`。** 仅仅 unset WAYLAND_DISPLAY 不够；GTK 仍可能找到默认的 wayland-0。现场曾出现会话本身是 `DISPLAY=:1`，子组件却尝试连接 `wayland-0`，最后只有一个空桌面窗口。
- `QT_QPA_PLATFORM=xcb`，会话类型设为 x11。
- 启动前 `cd "$HOME"`，使面板和应用继承 Linux 家目录。
- 新窗口创建前等待两秒，保留现场使用的 `-no-host-grab`。

## 5. 分开验证“有画面”和“能操作”

第一层：包存在、进程和 X11 窗口存在。只能证明软件启动到了某一步。

第二层：检查 **Windows 真正显示的画面**。WSL 内部截屏能得到正常桌面，但 Windows 上的 RAIL 窗口可能完全透明，任务栏缩略图是空白。现场两次误把进程和前台窗口 API 当成成功证据。

第三层：用户能展开应用菜单、移动窗口、在终端输入文字。现场在画面恢复后输入仍无响应，重新创建桌面会话后，用户才确认“有反应了”。

只有三层都成立，才说完整桌面可用了。`PrintWindow` 得到黑色也不能独立证明内容为空，因为某些图形合成窗口不支持该捕获方式；要结合实际屏幕和用户观察。

## 6. COPY MODE 的有效恢复

现场日志包含：

```text
rdp_allocate_shared_memory: Failed to open "/mnt/shared_memory/{...}" with error: Input/output error
RDP backend: use_gfxredir = 0
```

并且标题为 `[WARN:COPY MODE] ...`。同一日志中修复后的 `= 1` 会追加在旧 `= 0` 之后，因此必须取最后一条。

保存工作后，针对目标发行版的系统图形实例重启 Weston：

```powershell
wsl -d Ubuntu-24.04 --system --exec pkill -TERM -x weston
```

随后等待最新的 `use_gfxredir = 1`，再创建新的桌面会话。不要先无依据地重装桌面、改显卡驱动或挂载随机 tmpfs；系统发行版中的 `/mnt/shared_memory` 与用户发行版中的同名目录并不是一回事。

这一步会关闭 Linux 图形应用。它不是整套 WSL 关闭，但不能假设对未保存图形内容无影响。没有用户授权时，不要为了验证脚本而在正常环境执行。

参考：[microsoft/wslg#1456](https://github.com/microsoft/wslg/issues/1456)，包括其中针对 Weston 重启的讨论。本项目记录现场有效的临时恢复，不声称修复了 WSL 上游代码。

## 7. 终端目录与默认浏览器

不要在 `.bashrc` 中无条件 `cd ~`，那会破坏“在当前目录打开终端”等其他入口。

桌面会话本身从 `$HOME` 启动。已经存在的默认终端启动项加上 `Path=<家目录>` 和 `--working-directory=<家目录>`。不要照抄现场 `launcher-17`：项目使用来源标记查找默认入口。

浏览器启动项使用 `google-chrome-stable --ozone-platform=x11 %U`，Xfce 首选浏览器和 MIME 默认值指向 Chrome。不要运行 Chrome 的 root 图形会话，不要添加 `--no-sandbox`。

## 8. Chrome 验证的另一个坑

现场 Chrome 的 WM_CLASS 是 **Google-chrome-stable**。精确匹配 `"Google-chrome"` 会造成假失败；而一个 10×10 的辅助窗口也不能证明浏览器可见。查看窗口管理器维护的客户端列表和实际画面。

从一个很快退出的 WSL 验证脚本中执行 `nohup chrome &`，不能作为可靠的持久化方案。现场该路径结束时 Chrome 随后退出，并产生 GPU/zygote 错误。保持一次 `wsl.exe` 调用与 Chrome 生命周期一致后，浏览器窗口正常出现。不要仅根据收尾日志就断定显卡驱动坏了。

调试时可从 Windows 保持前台调用：

```powershell
wsl -d Ubuntu-24.04 --exec /home/yourname/.local/bin/wsl-xfce-app google-chrome-stable --ozone-platform=x11 about:blank
```

`wsl-xfce-app` 自动进入本项目桌面的显示和 D-Bus 上下文，最后用 `exec` 保持应用生命周期。日常点击桌面中的浏览器图标即可。

## 9. 对外发布前

只发布脚本、脱敏说明和测试。不要复制整个现场工作目录，其中可能有屏幕截图、个人目录列表、邮箱、主机名、用户配置或日志。清楚标注“现场验证”和“参数化后的自动检查”，不把模拟测试说成全新机器的完整验收。
