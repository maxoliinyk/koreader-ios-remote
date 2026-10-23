"""Check publication order and failure handling without connecting to GitHub."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/publish-release.sh"


class ReleasePublicationTests(unittest.TestCase):
    def run_publisher(self, existing="missing", fail_upload=False, missing_asset=False, tag="v2.0.0"):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            version = tag.removeprefix("v")
            for name in (f"KORemoteAltStore-{version}-unsigned.ipa", f"remote_turner-{version}.koplugin.zip", "SHA256SUMS"):
                if not (missing_asset and name == "SHA256SUMS"):
                    (folder / name).write_text("fixture")
            log = folder / "commands.jsonl"
            gh = folder / "gh"
            gh.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
command = sys.argv[2]
if command == "view":
    state = os.environ["EXISTING"]
    if state == "missing": sys.exit(1)
    print("true" if state == "draft" else "false")
if command == "upload" and os.environ["FAIL_UPLOAD"] == "1": sys.exit(1)
''')
            gh.chmod(0o755)
            environment = dict(os.environ, PATH=str(folder) + os.pathsep + os.environ["PATH"],
                               GH_REPO="example/koremote", DIST_DIR=str(folder), COMMAND_LOG=str(log),
                               EXISTING=existing, FAIL_UPLOAD=str(int(fail_upload)))
            result = subprocess.run(["sh", str(SCRIPT), tag], env=environment, capture_output=True)
            commands = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            notes = folder / "RELEASE_NOTES.md"
            return result.returncode, commands, notes.read_text() if notes.exists() else ""

    def test_accepts_short_development_version(self):
        status, commands, notes = self.run_publisher(tag="v0.5")
        self.assertEqual(status, 0)
        self.assertIn("--draft=false", commands[-1])
        self.assertTrue(any("KORemoteAltStore-0.5-unsigned.ipa#" in asset for asset in commands[-2]))
        self.assertIn("/blob/v0.5/README.md", notes)

    def test_rejects_invalid_version_before_contacting_github(self):
        status, commands, _ = self.run_publisher(tag="v0.5.0.1")
        self.assertNotEqual(status, 0)
        self.assertEqual(commands, [])

    def test_labels_assets_and_publishes_after_upload(self):
        status, commands, notes = self.run_publisher()
        self.assertEqual(status, 0)
        self.assertEqual([command[1] for command in commands], ["view", "create", "upload", "edit"])
        self.assertIn("--draft", commands[1])
        self.assertIn("--verify-tag", commands[1])
        self.assertTrue(any(asset.endswith("#KOReader Plugin") for asset in commands[2]))
        self.assertTrue(any(asset.endswith("#iOS IPA — AltStore Classic") for asset in commands[2]))
        self.assertIn("--draft=false", commands[-1])
        self.assertIn("https://github.com/example/koremote/blob/v2.0.0/README.md", notes)

    def test_upload_failure_leaves_release_as_draft(self):
        status, commands, _ = self.run_publisher(fail_upload=True)
        self.assertNotEqual(status, 0)
        self.assertEqual(commands[-1][1], "upload")
        self.assertFalse(any("--draft=false" in command for command in commands))

    def test_resumes_draft_but_preserves_published_release(self):
        status, commands, _ = self.run_publisher(existing="draft")
        self.assertEqual(status, 0)
        self.assertNotIn("create", [command[1] for command in commands])
        status, commands, _ = self.run_publisher(existing="published")
        self.assertNotEqual(status, 0)
        self.assertEqual(len(commands), 1)

    def test_missing_asset_never_contacts_github(self):
        status, commands, _ = self.run_publisher(missing_asset=True)
        self.assertNotEqual(status, 0)
        self.assertEqual(commands, [])
