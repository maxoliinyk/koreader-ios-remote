#!/usr/bin/env python3
"""Package only the KOReader plugin sources and their license."""

import argparse
from pathlib import Path
import re
import zipfile

REPO = Path(__file__).resolve().parent.parent
FILES = ("_meta.lua", "httpserver.lua", "main.lua")


def package(version: str, output: Path) -> Path:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", version):
        raise ValueError("Version must be 1–64 letters, digits, dots, underscores, or hyphens")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"remote_turner-{version}.koplugin.zip"
    # Fixed metadata makes repeated builds byte-for-byte reproducible.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        sources = [(REPO / "remote_turner.koplugin" / name, name) for name in FILES]
        sources.append((REPO / "LICENSE", "LICENSE"))
        for source, name in sources:
            info = zipfile.ZipInfo(f"remote_turner.koplugin/{name}")
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, source.read_bytes())
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", nargs="?", default="dev")
    parser.add_argument("--output", type=Path, default=REPO / "dist")
    args = parser.parse_args()
    try:
        print(package(args.version, args.output))
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
