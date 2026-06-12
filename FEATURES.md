# Features & how the system works

This document describes what the **Image Deepfake Detection** app does, how each check is calculated, and where the code lives.

---

## Overview

| Layer | Role |
|--------|------|
| **Next.js UI** (`frontend/`) | Upload JPG/PNG, view report, forensic maps, PDF download |
| **FastAPI** (`api/main.py`) | `POST /api/analyze` — full investigation |
| **7 evidence tools** | Deterministic Python checks (parallel) |
| **Fusion** (`api/agentic/tools/fusion.py`) | Combines scores into one **verdict** (math only) |
| **CrewAI** (`api/agentic/crew.py`) | Hierarchical agentic AI: **Crew Manager Agent** supervises specialists (OpenAI) |
| **On-device model** (`src/model/`) | EfficientNetB7 + attention, 128×128 input |

The UI shows **10 evidence rows**: 7 specialist checks, fusion, orchestration, and written summary.

---

## Investigation flow

1. Upload validated; **SHA-256** computed; temp working copy created.
2. **Seven evidence tools** run in parallel (thread pool).
3. If local OCR is empty, **Sightengine OCR text** may be merged into the OCR agent.
4. **`fuse_evidence()`** computes synthetic score, face score, verdict, and risk.
5. **CrewAI** runs (when `OPENAI_API_KEY` is set): **Crew Manager Agent** supervises specialists (hierarchical process, sequential fallback); tools are **re-run deterministically** so scores always match Python math; manager delivers final confidence.
6. Report saved in the browser (IndexedDB) and shown on `/results`.

Typical full run: **3–6 minutes** (local model + CrewAI + online API).

---

## Agents and tools

| ID | UI name | Source file | What it checks |
|----|---------|-------------|----------------|
| `local_model` | Local Model Agent | `api/agentic/tools/local_model.py` | EfficientNetB7 + attention; Grad-CAM heatmaps |
| `sightengine` | Sightengine Agent | `api/agentic/tools/sightengine.py` | Sightengine: AI-made, face deepfake, quality, OCR |
| `metadata` | Metadata & file signals | `api/agentic/tools/metadata.py` | EXIF, MIME, GPS, camera, AI tool tags, C2PA |
| `ocr` | OCR Agent | `api/agentic/tools/ocr_string.py` | Tesseract + regex (URLs, AI prompt hints) |
| `visual_forensics` | Noise and Sharpness Analysis Agent (UI merge) | `api/agentic/tools/visual_forensics.py` | ELA, noise, JPEG grid, FFT hints |
| `image_quality` | Image Quality & Compression Agent | `api/agentic/tools/image_quality.py` | Resolution, bpp, re-encode / compression flags |
| `face_region` | Noise and Sharpness Analysis Agent (UI merge) | `api/agentic/tools/face_region.py` | YuNet faces; sharpness vs background |
| `evidence_fusion` | Evidence Fusion Agent | `api/agentic/tools/fusion.py` | Weighted merge → verdict |
| `crew_manager` | Crew Manager Agent | `api/agentic/runner.py` + CrewAI | Supervises crew; final decision + confidence |
| `report_writer` | Report Writer Agent | CrewAI + `runner.py` | Plain-language sections |

Each evidence tool returns:

- `status` — `completed`, `skipped`, or `error`
- `score` — **0.0–1.0** (higher = more concern for that check)
- `summary`, `findings[]`, `data{}`
- Optional PNG maps (base64) for UI and PDF

The **risk %** on each card is `score × 100`. Only the **Combined assessment** at the top is the final fused verdict.

---

## 1. Local Model Agent

**Model:** `models/best_model_effatt.h5` (configurable via `MODEL_WEIGHTS_PATH` or `MODEL_REPO_ID` in `.env`).

**Preprocessing:** 128×128, BGR, float pixels 0–255 (training-matched pipeline in `src/preprocessing.py`).

**Calculation:**

- Forward pass → softmax → `prob_fake`, `prob_real` (optional temperature calibration via `MODEL_CALIBRATION_TEMPERATURE`).
- **`score` = `prob_fake`** (0–1).
- **Label:** class with higher probability (`Fake` = index 0, `Real` = index 1).

**Outputs:**

- Confidence and P(synthetic) / P(authentic) in the report header.
- **Grad-CAM** heatmap and overlay (`api/services/gradcam.py`) — shows where the model looked, not proof of editing.

---

## 2. Sightengine Agent

**Requires:** `SIGHTENGINE_API_USER` and `SIGHTENGINE_API_SECRET` in `.env`.

**API:** Single POST to Sightengine `check.json` with models `genai,deepfake,quality,ocr`.

| Field | Scale | Meaning |
|-------|--------|---------|
| AI-made (`genai_score`) | 0–1 | Higher = more likely AI-generated image |
| Face deepfake (`deepfake_score`) | 0–1 | Higher = more likely face swap / face manipulation |
| Picture clarity (`quality_score`) | 0–1 | Higher = **sharper/cleaner file** (not “more fake”) |
| OCR text / text-risk | — | Words in image; optional risk score |

**Agent `score`:** `max(genai_score, deepfake_score)` when both exist.

If credentials are missing, the agent still shows **completed** with a clear “not configured” message; fusion uses on-device checks only.

---

## 3. Metadata & file signals

**Tools:** ExifTool, `file`, ImageMagick `identify`, optional C2PA.

**Examples of findings:**

- MIME type, container, perceptual hash
- Camera make/model, software chain
- GPS and date fields (with separate meanings for capture vs file-modify time)
- AI generator names in metadata (tiered)
- Workflow flags (stripped EXIF, editor detected)

**Score:** Rule-based maximum (e.g. strong AI metadata tags → high score; normal phone EXIF → low score ~0.10–0.22).

Missing GPS alone is **not** treated as proof of a fake.

---

## 4. OCR Agent

**Local:** Tesseract (`TESSERACT_PATH` or system `tesseract`).

**Fallback:** If local OCR returns no text, Sightengine OCR may be merged in `runner.py` (`_merge_sightengine_ocr_into_ocr_report`).

**Score:** Pattern analysis on extracted text:

- AI prompt / watermark keywords → up to **0.85**
- High non-ASCII ratio, long character repeats → moderate bumps
- No suspicious patterns → **0**

A single stray character (e.g. `"9"`) is reported as minimal text, not a full sentence.

---

## 5. Visual statistics

**Methods** (OpenCV / NumPy / Pillow):

- **ELA** — error level after JPEG re-save
- **Laplacian** variance (sharpness)
- **Noise residual** energy
- **8×8 JPEG block** grid score
- **FFT** periodicity hint

**Score:** Starts at 0; heuristic thresholds raise it when artifacts look unusual.

**Maps:** ELA heatmap and noise residual map in the forensic gallery.

---

## 6. Compression & resolution

**Measures:**

- Width, height, megapixels
- Bytes per pixel (compression)
- Multi-quality ELA, re-encode spread
- Flags: `low_resolution`, `high_compression`, `reencoding_suspected`, `unreliable_for_verdict`

**Score:** Heuristic maximum from flags (very small or heavily compressed images score higher).

Poor quality can trigger **confidence limited** messaging without automatically meaning “fake.”

---

## 7. Face & partial-face cues

**Detector:** YuNet ONNX — `models/face_detection_yunet_2023mar.onnx`.

**Per face:**

- Sharpness and noise vs **background** (ratios)
- Partial face at image edge, small face in frame
- Optional duplicate-face texture hint

**Score:** `max()` across rules (e.g. sharpness ratio far from 1.0 → up to **0.55**).

A **high face risk %** on one row does not override a low fused verdict if the main model and online checks say authentic.

**Maps:** Face bounding box overlay and face-region saliency image.

---

## Evidence Fusion Agent (final verdict)

**File:** `api/agentic/tools/fusion.py`  
**Settings:** `api/agentic/context.py` and `.env` (`AGENTIC_W_*`, `AGENTIC_FUSION_CORE_BLEND`, default **0.85**).

### Synthetic score (whole-image)

**Core signals** (blended at 85% by default):

| Signal | Default weight |
|--------|----------------|
| Local model `prob_fake` | 0.45 |
| Sightengine AI-made | 0.25 |
| Sightengine OCR text-risk | 0.15 |

**Auxiliary signals** (15%):

| Signal | Default weight |
|--------|----------------|
| Visual forensics | 0.10 |
| Metadata | 0.08 |
| Local OCR string | 0.07 |
| Image quality | 0.12 |

Formula (simplified):

```text
synthetic_score = core_blend × weighted_avg(core) + (1 - core_blend) × weighted_avg(aux)
```

Missing agents are omitted from the average.

### Face-edit score

| Signal | Default weight |
|--------|----------------|
| Sightengine face deepfake | 0.25 |
| Face region tool | 0.25 |

Optional **+0.10** if partial faces plus strong compression flags.

### Verdict rules

| Condition | Verdict |
|-----------|---------|
| Face score ≥ 0.6 and ≥ synthetic | `likely_face_manipulated` |
| Synthetic ≥ 0.7 and ≥ 2 contributing sources | `likely_ai_generated` |
| Synthetic ≥ 0.7 and only 1 source | `needs_human_review` |
| Synthetic ≤ 0.35 and face ≤ 0.35 | `likely_authentic` |
| Otherwise | `needs_human_review` |

### Risk level

Based on `max(synthetic_score, face_swap_score)`:

- **≥ 0.7** → high  
- **≥ 0.4** → medium  
- **&lt; 0.4** → low  

**Human review** is flagged when agents disagree, quality is unreliable, or verdict is inconclusive.

---

## Forensic visuals in the UI

| Panel | Source |
|-------|--------|
| Uploaded image | Stored preview for this run |
| Heatmap (128×128) | Grad-CAM |
| Heatmap on your photo | Overlay |
| Face detection overlay | YuNet |
| Face-region saliency | Face tool |
| ELA re-compression map | Visual forensics |
| Noise residual map | Visual forensics |

Warm colors = where the **model or heuristic** paid attention. They are **hints**, not proof of Photoshop or face swap.

---

## API response (main fields)

| Field | Meaning |
|-------|---------|
| `label`, `prob_fake`, `prob_real`, `confidence_percent` | Local model (legacy-compatible) |
| `heatmap_png_base64`, `overlay_png_base64` | Maps |
| `verdict`, `risk_level`, `needs_human_review` | Fusion output |
| `agents[]` | Per-agent reports |
| `evidence` | Nested tool payloads |
| `investigation_log[]` | Step-by-step audit |
| `image_sha256` | File fingerprint |
| `investigation_ms` | Total time |

---

## Project layout (code map)

```text
Image Deepfake Detection/
├── setup.sh, start.sh       # Install deps / start both servers
├── package.json             # npm start → API + frontend
├── .env, .env.example       # Keys and paths
├── README.md                # Quick setup
├── FEATURES.md              # This file
├── models/
│   ├── best_model_effatt.h5
│   └── face_detection_yunet_2023mar.onnx
├── frontend/
│   └── src/app, components, lib   # UI, copy, PDF, session storage
├── api/
│   ├── main.py              # FastAPI
│   └── agentic/
│       ├── runner.py        # Parallel tools + response build
│       ├── crew.py, agents.py, tasks.py
│       ├── context.py, schemas.py
│       └── tools/           # All evidence agents + fusion + safety
├── src/model/loader.py      # TensorFlow weights
└── scripts/
    ├── install-analysis-deps-ubuntu.sh
    └── run_all_agents_test.py   # Test tools without OpenAI
```

---

## Configuration (.env)

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | Required for full `/api/analyze` (CrewAI) |
| `OPENAI_MODEL` | e.g. `gpt-4o-mini` |
| `SIGHTENGINE_API_USER` / `SECRET` | Sightengine Agent |
| `MODEL_WEIGHTS_PATH` / `MODEL_REPO_ID` | Detector weights |
| `AGENTIC_W_LOCAL`, `AGENTIC_W_SIGHTENGINE_*`, … | Fusion weights |
| `AGENTIC_FUSION_CORE_BLEND` | Core vs auxiliary blend (default 0.85) |
| `EXIFTOOL_PATH`, `TESSERACT_PATH` | Optional binary paths |

See `.env.example` for the full list.

---

## How to read a report (example)

For a **likely authentic** photo with:

- Main model **~92% real**, P(fake) **~8%**
- Online AI **0.00**, face fake **0.01**, quality **0.96**
- Fusion synthetic **0.05**, face **0.28**, risk **low**

→ Checks agree the image **looks like a normal photo**. A single **face texture mismatch** line is a weak cue (common in real phone photos) and is **down-weighted** in fusion.

---


