#!/usr/bin/env python3
"""Run every evidence agent + fusion on one image (no CrewAI/OpenAI)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "api"))
sys.path.insert(0, str(ROOT / "src"))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")

from agentic.context import AgenticSettings, build_context
from agentic.runner import EVIDENCE_AGENT_DEFINITIONS
from agentic.tools.fusion import fuse_evidence


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/ubuntu/Downloads/camera-bathers.jpeg")
    if not path.is_file():
        print(f"Missing: {path}", file=sys.stderr)
        return 1

    settings = AgenticSettings.from_env()
    data = path.read_bytes()
    ctx = build_context(data, path.name, settings=settings)

    print(f"Image: {path.name} ({len(data)} bytes, {ctx.width}x{ctx.height})")
    print(f"SHA-256: {ctx.sha256[:16]}…")
    print(f"Sightengine configured: {bool(settings.sightengine_user and settings.sightengine_secret)}")
    print("-" * 60)

    reports = {}
    try:
        skipped_any = False
        for agent_id, display_name, fn in EVIDENCE_AGENT_DEFINITIONS:
            rep = fn(ctx)
            reports[agent_id] = rep
            status = rep.get("status")
            score = rep.get("score")
            summary = (rep.get("summary") or "")[:72]
            err = rep.get("error")
            if status == "skipped":
                skipped_any = True
            print(f"[{status:9}] {display_name:32} score={score!s:6}  {summary}")
            if err:
                print(f"           error: {str(err)[:120]}")
            lim = rep.get("limitations") or []
            if status == "skipped" and lim:
                print(f"           note: {lim[0][:100]}")
        if skipped_any:
            print("WARNING: one or more agents still report status=skipped — install deps or fix config.")
        else:
            print("All evidence agents completed (none skipped).")

        fusion = fuse_evidence(reports, settings.fusion_weights, settings.fusion_core_blend)
        print("-" * 60)
        print(f"FUSION verdict={fusion.verdict.value} risk={fusion.risk_level.value}")
        print(f"         synthetic_score={fusion.synthetic_score} face_swap_score={fusion.face_swap_score}")
        print(f"         needs_human_review={fusion.needs_human_review}")
        if fusion.contradictions:
            print("Contradictions:")
            for c in fusion.contradictions:
                print(f"  - {c}")

        md = reports.get("metadata", {}).get("data") or {}
        gps = md.get("gps_coordinates") or {}
        print("-" * 60)
        print("Metadata highlights:")
        print(f"  GPS: {gps.get('display', gps)}")
        print(f"  Camera: {md.get('camera')}")
        print(f"  AI tier: {md.get('metadata_ai_tier')}")
        print(f"  pHash: {md.get('perceptual_hash')}")

        iq = reports.get("image_quality", {}).get("data") or {}
        print("Quality flags:", iq.get("quality_flags"))

        fr = reports.get("face_region", {}).get("data") or {}
        print(f"Face: detector={fr.get('detector')} count={fr.get('faces_detected')} partial={fr.get('partial_faces_detected')}")

        vf = reports.get("visual_forensics", {}).get("data") or {}
        print(
            "Visual maps:",
            "ELA" if vf.get("ela_heatmap_png_base64") else "no-ELA",
            "noise" if vf.get("noise_residual_map_png_base64") else "no-noise",
        )

        lm = reports.get("local_model", {}).get("data") or {}
        print(
            f"Neural: {lm.get('label')} conf={lm.get('confidence_percent')}% "
            f"P(fake)={lm.get('prob_fake')} heatmap={'yes' if lm.get('heatmap_png_base64') else 'no'}"
        )

        se = reports.get("sightengine", {})
        print(f"Sightengine: status={se.get('status')} summary={(se.get('summary') or '')[:80]}")

        return 0
    finally:
        ctx.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
