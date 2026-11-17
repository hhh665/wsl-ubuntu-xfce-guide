from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("panel_configuration", REPO / "linux/configure-panel.py")
panel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(panel)


class PanelConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="wsl xfce configuration ")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)

    def launcher(self, number, name, body):
        path = self.home / f".config/xfce4/panel/launcher-{number}/{name}.desktop"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("[Desktop Entry]\nType=Application\n" + body, encoding="utf-8")
        return path

    def test_arbitrary_ids_home_spaces_and_actions(self):
        terminal = self.launcher(431, "random", "Exec=exo-open --launch TerminalEmulator\nName=Terminal\n"
            "[Desktop Action Special]\nExec=leave-this-action-alone\n")
        browser = self.launcher(892, "browser", "Exec=exo-open --launch WebBrowser %u\nName=Browser\n")
        custom = self.launcher(9, "custom", "Exec=my-custom-terminal --here\nName=Custom\n")
        custom_original = custom.read_bytes()
        panel.configure(self.home, True)
        self.assertEqual(panel.value(terminal.read_text(), "Path"), str(self.home))
        self.assertEqual(panel.value(terminal.read_text(), "Exec"), f'xfce4-terminal --working-directory="{self.home}"')
        self.assertIn("[Desktop Action Special]\nExec=leave-this-action-alone", terminal.read_text())
        self.assertIn("--ozone-platform=x11 %U", panel.value(browser.read_text(), "Exec"))
        self.assertEqual(custom.read_bytes(), custom_original)

    def test_repeated_execution_preserves_first_backup_and_other_preferences(self):
        terminal = self.launcher(77, "default", "Exec=exo-open --launch TerminalEmulator\n"
            "X-XFCE-Source=file:///usr/share/applications/xfce4-terminal-emulator.desktop\n")
        original = terminal.read_bytes()
        config = self.home / ".config"
        (config / "xfce4").mkdir(parents=True, exist_ok=True)
        (config / "xfce4/helpers.rc").write_text("TerminalEmulator=my-terminal\nWebBrowser=old-browser\n")
        (config / "mimeapps.list").write_text("[Default Applications]\nimage/png=my-viewer.desktop;\n")
        panel.configure(self.home, True)
        once = terminal.read_bytes()
        mime_once = (config / "mimeapps.list").read_bytes()
        panel.configure(self.home, True)
        self.assertEqual(terminal.read_bytes(), once)
        self.assertEqual((config / "mimeapps.list").read_bytes(), mime_once)
        self.assertEqual(terminal.with_name(terminal.name + ".wsl-xfce.bak").read_bytes(), original)
        self.assertIn("TerminalEmulator=my-terminal", (config / "xfce4/helpers.rc").read_text())
        self.assertIn("image/png=my-viewer.desktop;", (config / "mimeapps.list").read_text())

    def test_no_chrome_does_not_change_browser(self):
        browser = self.launcher(33, "browser", "Exec=exo-open --launch WebBrowser %u\n")
        original = browser.read_bytes()
        panel.configure(self.home, False)
        self.assertEqual(browser.read_bytes(), original)
        self.assertFalse((self.home / ".config/mimeapps.list").exists())


class StopProcessSafetyTests(unittest.TestCase):
    def run_stop(self, root, pid):
        import os
        runtime = root / "runtime/wsl-xfce-desktop"
        runtime.mkdir(parents=True)
        (runtime / "desktop.pid").write_text(str(pid))
        environment = os.environ.copy()
        environment.update(HOME=str(root / "home"), XDG_RUNTIME_DIR=str(root / "runtime"))
        return subprocess.run(["bash", str(REPO / "linux/stop-xfce-desktop")],
            env=environment, capture_output=True, text=True, timeout=5)

    def test_unrelated_owned_process_survives(self):
        sleeper = subprocess.Popen(["sleep", "30"])
        try:
            with tempfile.TemporaryDirectory() as directory:
                result = self.run_stop(Path(directory), sleeper.pid)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(sleeper.poll())
                self.assertIn("refusing", result.stderr.lower())
        finally:
            sleeper.terminate()
            sleeper.wait(timeout=5)

    def test_stale_pid_is_harmless(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_stop(Path(directory), 2**30)
            self.assertEqual(result.returncode, 0)
            self.assertIn("already stopped", result.stdout)


if __name__ == "__main__":
    unittest.main()
