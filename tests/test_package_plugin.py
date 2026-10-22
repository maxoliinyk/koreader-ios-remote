"""Release archive contract; run with python3 -m unittest discover -s tests."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "package_plugin", Path(__file__).resolve().parents[1] / "scripts/package-plugin.py"
)
PACKAGER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGER)


class PluginArchiveTests(unittest.TestCase):
    def test_archive_contains_only_installable_sources_and_license(self):
        with tempfile.TemporaryDirectory() as directory:
            path = PACKAGER.package("test", Path(directory))
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(set(archive.namelist()), {
                    "remote_turner.koplugin/_meta.lua", "remote_turner.koplugin/httpserver.lua",
                    "remote_turner.koplugin/main.lua", "remote_turner.koplugin/LICENSE",
                })
            first = path.read_bytes()
            self.assertEqual(first, PACKAGER.package("test", Path(directory)).read_bytes())

    def test_rejects_unsafe_or_empty_labels_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            for label in ("", "../release", "a/b", "a b", "-release", "a" * 65):
                with self.subTest(label=label), self.assertRaises(ValueError):
                    PACKAGER.package(label, Path(directory))
            self.assertEqual(list(Path(directory).iterdir()), [])
