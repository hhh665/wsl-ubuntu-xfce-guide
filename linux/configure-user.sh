#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo 'Configure the desktop as a normal Linux user.' >&2; exit 1; }
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
with_chrome=false
case "${1:-}" in '') ;; --chrome) with_chrome=true ;; *) exit 2 ;; esac
if $with_chrome; then
    command -v google-chrome-stable >/dev/null || { echo 'Install Chrome first.' >&2; exit 1; }
fi
install -Dm755 "$source_dir/start-xfce-desktop" "$HOME/.local/bin/start-xfce-desktop"
install -Dm755 "$source_dir/stop-xfce-desktop" "$HOME/.local/bin/stop-xfce-desktop"
install -Dm755 "$source_dir/wsl-xfce-app" "$HOME/.local/bin/wsl-xfce-app"
install -Dm755 "$source_dir/diagnose.sh" "$HOME/.local/bin/wsl-xfce-diagnose"
install -Dm644 "$source_dir/desktop-context.sh" "$HOME/.local/share/wsl-xfce/desktop-context.sh"
mkdir -p "$HOME/.local/share/applications" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat >"$HOME/.local/share/applications/wsl-xfce-desktop.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Ubuntu Desktop (Xfce)
Name[zh_CN]=Ubuntu 桌面
Exec="$HOME/.local/bin/start-xfce-desktop"
Icon=preferences-desktop
Terminal=false
Categories=System;
StartupNotify=false
DESKTOP
panel_config="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
if [[ ! -e "$panel_config" && -f /etc/xdg/xfce4/panel/default.xml ]]; then
    cp /etc/xdg/xfce4/panel/default.xml "$panel_config"
fi
panel_arguments=(--home "$HOME")
if $with_chrome; then panel_arguments+=(--chrome); fi
python3 "$source_dir/configure-panel.py" "${panel_arguments[@]}"
update-desktop-database "$HOME/.local/share/applications"
echo 'USER_CONFIGURED'
