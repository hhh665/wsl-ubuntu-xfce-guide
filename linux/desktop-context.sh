#!/usr/bin/env bash
# Source this file from wsl-xfce-app or diagnostics; never dump full /proc environ.
load_desktop_context() {
    local runtime_dir candidate candidate_display bus_address
    runtime_dir="${XDG_RUNTIME_DIR:-/tmp/wsl-desktop-$UID}/wsl-xfce-desktop"
    [[ -r "$runtime_dir/display" && -r "$runtime_dir/Xauthority" ]] || {
        echo 'Start the managed Xfce desktop first.' >&2; return 1;
    }
    export DISPLAY="$(cat "$runtime_dir/display")"
    export XAUTHORITY="$runtime_dir/Xauthority"
    export GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb
    export XDG_CURRENT_DESKTOP=XFCE XDG_SESSION_TYPE=x11
    export LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh
    unset WAYLAND_DISPLAY SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
    for candidate in $(pgrep -u "$UID" -x xfce4-session || true); do
        [[ -r "/proc/$candidate/environ" ]] || continue
        candidate_display="$(tr '\0' '\n' <"/proc/$candidate/environ" | sed -n 's/^DISPLAY=//p')"
        [[ "$candidate_display" == "$DISPLAY" ]] || continue
        bus_address="$(tr '\0' '\n' <"/proc/$candidate/environ" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')"
        [[ -n "$bus_address" ]] || continue
        export DBUS_SESSION_BUS_ADDRESS="$bus_address"
        return 0
    done
    echo 'The managed desktop session bus was not found.' >&2
    return 1
}
