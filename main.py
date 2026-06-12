"""
FastAPI inference API for the Next.js frontend.

Per the agentic implementation plan, `POST /api/analyze` runs the full
9-agent CrewAI investigation. There is no longer a "fast path"; the
endpoint always returns the structured agentic response.
"""

from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None  # type: ignore[assignment, misc]

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

ROOT = Path(__file__).resolve().parent.parent
_API_DIR = Path(__file__).resolve().parent
if load_dotenv is not None:
    # Project root .env (recommended), then api/.env — latter overrides for local dev.
    load_dotenv(ROOT / ".env")
    load_dotenv(_API_DIR / ".env", override=True)
sys.path.insert(0, str(ROOT / "src"))

from model.loader import IMAGE_SIZE, load_model  # noqa: E402

from api.agentic import (  # noqa: E402
    AgenticConfigurationError,
    run_agentic_investigation,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    force=True,
)
logger = logging.getLogger(__name__)

MODEL_INFO = {
    "architecture": "EfficientNetB7 + custom spatial attention + dense head",
    "input_size": [IMAGE_SIZE, IMAGE_SIZE, 3],
    "classes": ["Fake", "Real"],
    "localization_method": "Grad-CAM on EfficientNetB7 conv features; falls back to input-gradient saliency (128x128) if needed",
    "reported_notes": {
        "inference_cpu_seconds": "about 2-3 s per image on a typical laptop CPU",
        "inference_gpu_seconds": "often under 1 s with a mid-range GPU",
        "paper": "See model documentation for training data and evaluation metrics.",
    },
    "agentic_mode": {
        "endpoint": "/api/analyze",
        "description": "CrewAI-orchestrated multi-agent forensic investigation around the local detector.",
        "process": "hierarchical (CrewAI manager_agent + 8 specialists)",
        "agents": [
            "Crew Manager Agent",
            "Local Model Agent",
            "Sightengine Agent",
            "Metadata Agent",
            "OCR Agent",
            "Noise and Sharpness Analysis Agent",
            "Image Quality & Compression Agent",
            "Evidence Fusion Agent",
            "Report Writer Agent",
        ],
    },
}


app = FastAPI(title="Image Deepfake Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    model = load_model()
    return {"status": "ok" if model is not None else "degraded", "model_loaded": model is not None}


@app.get("/api/meta")
def meta():
    return MODEL_INFO


@app.post("/api/analyze")
async def analyze(file: UploadFile = File(...)):
    """Run the full CrewAI-driven agentic investigation on the upload.

    Returns backwards-compatible fields (label, confidence_percent,
    prob_fake, prob_real, heatmap/overlay base64) plus per-agent
    reports for all 9 agents, an evidence bundle, the fused verdict,
    contradictions, risk level, and a needs_human_review flag.

    Returns 503 when `OPENAI_API_KEY` is missing - the agentic system
    requires it.
    """
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Empty file.")
    name = file.filename or "upload"
    logger.info("analyze_start filename=%s bytes=%s", name, len(raw))
    try:
        # CrewAI kickoff uses async internally; must not run on FastAPI's event loop thread.
        out = await asyncio.to_thread(run_agentic_investigation, raw, name)
        logger.info(
            "analyze_done filename=%s verdict=%s ms=%s",
            name,
            out.get("verdict"),
            out.get("investigation_ms"),
        )
        return out
    except AgenticConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        logger.exception("Agentic investigation failed.")
        raise HTTPException(status_code=500, detail="Agentic investigation failed.")

