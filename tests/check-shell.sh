#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
for script in linux/*.sh linux/start-xfce-desktop linux/stop-xfce-desktop linux/wsl-xfce-app tests/check-shell.sh; do
    bash -n "$script"
done
echo 'BASH_SYNTAX_OK'
