#!/usr/bin/env python3
"""Configure known default Xfce launchers without assuming plugin numbers."""
from __future__ import annotations

import argparse
import configparser
import re
import shutil
from pathlib import Path


def value(text: str, key: str) -> str:
    section = text.split("[Desktop Entry]", 1)[-1].split("\n[", 1)[0]
    match = re.search(rf"^{re.escape(key)}=(.*)$", section, re.MULTILINE)
    return match.group(1) if match else ""


def set_entry(text: str, key: str, new_value: str) -> str:
    """Modify only the main Desktop Entry, preserving actions and translations."""
    before, separator, remaining = text.partition("[Desktop Entry]")
    if not separator:
        raise ValueError("Missing Desktop Entry section")
    section, next_separator, actions = remaining.partition("\n[")
    pattern = rf"^{re.escape(key)}=.*$"
    replacement = f"{key}={new_value}"
    if re.search(pattern, section, re.MULTILINE):
        section = re.sub(pattern, lambda _: replacement, section, flags=re.MULTILINE)
    else:
        section = section.rstrip("\n") + "\n" + replacement + "\n"
    return before + separator + section + (next_separator + actions if next_separator else "")


def backup(path: Path) -> None:
    backup_path = path.with_name(path.name + ".wsl-xfce.bak")
    if path.exists() and not backup_path.exists():
        shutil.copy2(path, backup_path)


def configure(home: Path, with_chrome: bool) -> list[str]:
    changed = []
    for launcher in sorted((home / ".config/xfce4/panel").glob("launcher-*/*.desktop")):
        original = launcher.read_text(encoding="utf-8")
        text = original
        source = value(text, "X-XFCE-Source")
        command = value(text, "Exec")
        if source.endswith("/xfce4-terminal-emulator.desktop") or command == "exo-open --launch TerminalEmulator":
            text = set_entry(text, "Exec", f'xfce4-terminal --working-directory="{home}"')
            text = set_entry(text, "Path", str(home))
        if with_chrome and (source.endswith("/xfce4-web-browser.desktop") or command == "exo-open --launch WebBrowser %u"):
            for key, new_value in {
                "Exec": "google-chrome-stable --ozone-platform=x11 %U",
                "Path": str(home), "Icon": "google-chrome", "Name": "Google Chrome",
                "Name[zh_CN]": "Google Chrome 浏览器",
            }.items():
                text = set_entry(text, key, new_value)
        if text != original:
            backup(launcher)
            launcher.write_text(text, encoding="utf-8")
            changed.append(str(launcher.relative_to(home)))
    if with_chrome:
        helpers = home / ".config/xfce4/helpers.rc"
        helpers.parent.mkdir(parents=True, exist_ok=True)
        old = helpers.read_text(encoding="utf-8") if helpers.exists() else ""
        if re.search(r"^WebBrowser=.*$", old, re.MULTILINE):
            new = re.sub(r"^WebBrowser=.*$", "WebBrowser=google-chrome", old, flags=re.MULTILINE)
        else:
            new = old.rstrip("\n") + ("\n" if old else "") + "WebBrowser=google-chrome\n"
        if new != old:
            backup(helpers)
            helpers.write_text(new, encoding="utf-8")
        mimeapps = home / ".config/mimeapps.list"
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        if mimeapps.exists():
            parser.read(mimeapps, encoding="utf-8")
        if not parser.has_section("Default Applications"):
            parser.add_section("Default Applications")
        for mime in ("text/html", "x-scheme-handler/http", "x-scheme-handler/https"):
            parser.set("Default Applications", mime, "google-chrome.desktop;")
        backup(mimeapps)
        with mimeapps.open("w", encoding="utf-8") as handle:
            parser.write(handle, space_around_delimiters=False)
    return changed


if __name__ == "__main__":
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--home", type=Path, default=Path.home())
    arguments.add_argument("--chrome", action="store_true")
    args = arguments.parse_args()
    for item in configure(args.home.resolve(), args.chrome):
        print(f"Updated: {item}")
