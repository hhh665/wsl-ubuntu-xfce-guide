#!/usr/bin/env bash
set -u
printf 'USER: '; id
printf '\nSYSTEM:\n'; head -6 /etc/os-release
printf '\nGRAPHICS MODE (latest entry):\n'
awk '/RDP backend: use_gfxredir =/{last=$0} END {print last}' /mnt/wslg/weston.log 2>/dev/null
printf '\nGRAPHICS ALLOCATION ERRORS (last 3):\n'
grep 'rdp_allocate_shared_memory: Failed' /mnt/wslg/weston.log 2>/dev/null | tail -3
printf '\nDESKTOP PROCESSES:\n'
for component in Xephyr xfce4-session xfwm4 xfce4-panel xfdesktop; do
    pgrep -u "$UID" -x "$component" || true
done
printf '\nPACKAGE VERSIONS:\n'
dpkg-query -W xfce4 xserver-xephyr google-chrome-stable 2>/dev/null || true
printf '\nAPT BACKGROUND SERVICE:\n'
systemctl is-active apt-daily-upgrade.service 2>/dev/null || true
printf '\nPackage installer processes:\n'; pgrep -a -x dpkg || true
printf '\nLOG: ~/.local/state/wsl-xfce-desktop/session.log\n'
printf 'These checks do not prove Windows pixels or input work. Confirm both in the UI.\n'
