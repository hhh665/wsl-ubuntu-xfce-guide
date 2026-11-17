#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run this package installer as root.' >&2; exit 1; }
with_chrome=false
case "${1:-}" in
    '') ;;
    --chrome) with_chrome=true ;;
    *) echo 'Usage: install-packages.sh [--chrome]' >&2; exit 2 ;;
esac
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || {
    echo 'This installer targets Ubuntu 24.04. Inspect the guide for other systems.' >&2
    exit 1
}
if $with_chrome && [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    echo 'Google Chrome Linux .deb requires amd64. Do not install it on arm64.' >&2
    exit 1
fi
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
apt_options=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
    -o Acquire::http::Timeout=30 -o Dpkg::Options::=--force-confold)
apt-get "${apt_options[@]}" update
apt-get "${apt_options[@]}" -y --no-install-recommends install \
    xfce4 xserver-xephyr dbus-x11 xfce4-terminal xfce4-screenshooter \
    x11-utils xauth fonts-noto-cjk language-pack-zh-hans locales \
    desktop-file-utils python3 curl ca-certificates
locale-gen zh_CN.UTF-8
install -d -m1777 -o root -g root /tmp/.ICE-unix

if $with_chrome; then
    if dpkg-query -W -f='${Status}' google-chrome-stable 2>/dev/null | grep -qx 'install ok installed'; then
        echo 'Chrome is already installed; leaving its current version in place.'
    else
        download_dir="$(mktemp -d /var/tmp/wsl-xfce-chrome.XXXXXX)"
        trap 'rm -f "$download_dir/chrome.deb"; rmdir "$download_dir"' EXIT
        chrome_package="$download_dir/chrome.deb"
        curl --fail --location --retry 2 --connect-timeout 15 --max-time 300 \
            --output "$chrome_package" \
            https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        [[ "$(dpkg-deb --field "$chrome_package" Package)" == google-chrome-stable ]]
        [[ "$(dpkg-deb --field "$chrome_package" Architecture)" == amd64 ]]
        apt-get "${apt_options[@]}" -y --no-install-recommends install "$chrome_package"
    fi
    google-chrome-stable --version
fi
echo 'PACKAGES_INSTALLED'
