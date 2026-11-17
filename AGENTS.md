# Instructions for AI agents

Read `docs/AI_RUNBOOK.md` before changing a real WSL environment.

## Scope

This repository configures an existing Ubuntu 24.04 WSL 2 distribution. Discover
the actual Windows identity, distribution, Linux user and home directory. Do not
create or reinstall a distribution just because an isolated execution account
reports an empty WSL list. Do not hard-code the original machine's account,
Windows path, plugin number, or X display number.

## Changes and validation

- Preserve existing user configuration. Match default launcher metadata, not a
  guessed `launcher-17` or `launcher-19` directory.
- Use `GDK_BACKEND=x11`, an independent Xauthority file, and a separate D-Bus
  session. Never add `--no-sandbox` to Chrome as a generic fix.
- Read the LAST `use_gfxredir` entry. Restarting Weston closes graphical apps;
  obtain the relevant user authorization before a live recovery. Avoid a full
  WSL shutdown when a targeted graphical recovery is sufficient.
- A GUI process, native window handle, or successful foreground API call is not
  proof of a visible, interactive desktop. Check actual Windows pixels and ask
  the user to click a menu. Record visibility and input as separate results.
- Do not remove APT lock files or blindly kill unattended-upgrades. The package
  installer waits and fails safely; manual recovery is documented separately.
- Do not run graphical applications as root. Do not upload raw logs, screenshots,
  browser profiles, home-directory listings, credentials, or personal paths.
- Keep app launches attached to a suitable long-lived WSL invocation. Do not
  assume `nohup ... &` from a short-lived verification command will suffice.

Run the Linux and Windows checks from README for relevant changes. Preserve the
distinction between the observed original session and portability changes that
have not been tested on a clean machine. Do not claim a fix merely from lint or
process checks. Do not restart the user's working desktop just to test docs.
