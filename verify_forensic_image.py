#!/usr/bin/env python3
"""Run forensic tools on one image (no OpenAI / CrewAI). Usage:
  python3 scripts/verify_forensic_image.py ~/Downloads/camera-bathers.jpeg
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "api"))
sys.path.insert(0, str(ROOT / "src"))

from agentic.context import build_context, AgenticSettings
from agentic.tools.metadata import run_metadata
from agentic.tools.image_quality import run_image_quality
from agentic.tools.face_region import run_face_region
from agentic.tools.visual_forensics import run_visual_forensics


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: verify_forensic_image.py <image-path>", file=sys.stderr)
        return 1
    path = Path(sys.argv[1]).expanduser()
    if not path.is_file():
        print(f"Not found: {path}", file=sys.stderr)
        return 1
    data = path.read_bytes()
    ctx = build_context(data, path.name, settings=AgenticSettings.from_env())
    try:
        reports = {
            "metadata": run_metadata(ctx),
            "image_quality": run_image_quality(ctx),
            "face_region": run_face_region(ctx),
            "visual_forensics": run_visual_forensics(ctx),
        }
        out = {
            k: {
                "status": v.get("status"),
                "summary": v.get("summary"),
                "score": v.get("score"),
                "findings": v.get("findings"),
                "data_keys": list((v.get("data") or {}).keys()),
                "data": {
                    kk: vv
                    for kk, vv in (v.get("data") or {}).items()
                    if not str(kk).endswith("_png_base64")
                    and kk != "exiftool"
                },
            }
            for k, v in reports.items()
        }
        print(json.dumps(out, indent=2, default=str))
        md = reports["metadata"].get("data") or {}
        gps = md.get("gps_coordinates") or {}
        if gps:
            print("\nGPS check:", gps.get("display") or gps)
        cam = md.get("camera") or {}
        if cam:
            print("Camera:", cam)
        return 0
    finally:
        ctx.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
