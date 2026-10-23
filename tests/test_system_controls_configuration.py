"""Protect locked-screen controls across distribution configurations."""
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class SystemControlsConfigurationTests(unittest.TestCase):
    def test_full_declares_background_audio(self):
        with (REPO / "App/Info.plist").open("rb") as source:
            configuration = plistlib.load(source)
        self.assertIn("audio", configuration.get("UIBackgroundModes", []))

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is unavailable")
    def test_every_distribution_keeps_locked_controls(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            main = folder / "main.swift"
            main.write_text('''//
//  main.swift
//  KORemote
//
//  Created by Max Oliinyk on 23.10.26.
//
for profile in [DistributionProfile.full, .personalTeam, .altStore] {
    print("\\(profile.title):\\(profile.keepsVolumeCaptureWhileInactive):\\(profile.supportsMediaControls)")
}
''')
            binary = folder / "check-controls"
            subprocess.run(["swiftc", str(REPO / "App/DistributionProfile.swift"), str(main),
                            "-o", str(binary)], check=True, capture_output=True, text=True)
            result = subprocess.run([str(binary)], check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.splitlines(), [
                "Full:true:true", "Personal Team:true:true", "AltStore Classic:true:true",
            ])
