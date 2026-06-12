#!/usr/bin/env python3
"""Create a clean zip for moving the project to another PC."""

from __future__ import annotations

import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
PROJECT_NAME = ROOT.name
DEFAULT_OUTPUT = ROOT.parent / f"{PROJECT_NAME.replace(' ', '-')}-portable.zip"

SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "node_modules",
    ".next",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
}

SKIP_FILES = {
    ".env",
    ".env.local",
}

SKIP_SUFFIXES = {
    ".pyc",
    ".pyo",
}


def should_skip(path: Path, output: Path) -> bool:
    rel = path.relative_to(ROOT)
    parts = set(rel.parts)
    if parts & SKIP_DIRS:
        return True
    if path.name in SKIP_FILES:
        return True
    if path.suffix.lower() in SKIP_SUFFIXES:
        return True
    if path == ROOT:
        return False
    if path.resolve() == output.resolve():
        return True
    return False


def main() -> int:
    output = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_OUTPUT
    output.parent.mkdir(parents=True, exist_ok=True)

    count = 0
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as zf:
        for path in sorted(ROOT.rglob("*")):
            if path.is_dir() or should_skip(path, output):
                continue
            arcname = Path(PROJECT_NAME) / path.relative_to(ROOT)
            zf.write(path, arcname)
            count += 1

    print(f"Wrote: {output}")
    print(f"Files: {count}")
    print("Excluded: .venv, node_modules, frontend/.next, .git, .env")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
