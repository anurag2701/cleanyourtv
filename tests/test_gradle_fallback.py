"""launcher/gradle-fallback.ps1: the offline checks in tests/gradle_fallback_check.ps1, run through Windows PowerShell.

The script is Windows-only, so this skips anywhere PowerShell is missing. It checks the pure parts (reading the
wrapper properties, spotting a failed Gradle download, verifying the pinned SHA-256, rewriting and restoring
distributionUrl); the download and the build themselves need a real network and a JDK."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECK = ROOT / "tests" / "gradle_fallback_check.ps1"
POWERSHELL = shutil.which("powershell") or shutil.which("pwsh")


class GradleFallbackTest(unittest.TestCase):
    @unittest.skipUnless(POWERSHELL, "PowerShell not available")
    def test_offline_checks_pass(self):
        run = subprocess.run([POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(CHECK)],
                             capture_output=True, text=True, timeout=120)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn("all checks passed", run.stdout)
        self.assertNotIn("FAIL", run.stdout)

    def test_the_build_script_uses_the_fallback(self):
        text = (ROOT / "launcher" / "build-and-install.ps1").read_text(encoding="utf-8")
        self.assertIn("gradle-fallback.ps1", text)
        self.assertIn("Invoke-GradleBuild", text)


if __name__ == "__main__":
    unittest.main()
