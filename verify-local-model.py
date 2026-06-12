#!/usr/bin/env python3
"""Quick check that the local TensorFlow detector loads and scores an image."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "api"))
sys.path.insert(0, str(ROOT / "src"))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")


def should_force_cpu() -> bool:
    if os.environ.get("FORCE_CPU_INFERENCE", "").lower() in ("1", "true", "yes"):
        return True
    if os.environ.get("FORCE_CPU_INFERENCE", "").lower() in ("0", "false", "no"):
        return False
    return True


if should_force_cpu():
    os.environ.setdefault("FORCE_CPU_INFERENCE", "1")
    os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")


def main() -> int:
    weights = ROOT / "models" / "best_model_effatt.h5"
    print(f"Project: {ROOT}")
    print(f"Weights file: {weights} -> {'OK' if weights.is_file() else 'MISSING'}")
    print(f"FORCE_CPU_INFERENCE: {os.environ.get('FORCE_CPU_INFERENCE', '(not set)')}")
    print("-" * 60)

    from model.loader import load_model, model_provenance

    model = load_model()
    if model is None:
        print("FAIL: model did not load.")
        print("Fix: run ./setup.sh on this machine (do not copy .venv from another PC),")
        print("     add models/best_model_effatt.h5, set FORCE_CPU_INFERENCE=1 if CUDA errors.")
        return 1

    prov = model_provenance()
    print(f"OK: model loaded ({prov.get('model_source')}, keras {prov.get('keras_version')})")

    if len(sys.argv) < 2:
        print("Tip: pass an image path to run a test prediction:")
        print("  python scripts/verify-local-model.py /path/to/photo.jpg")
        return 0

    img_path = Path(sys.argv[1])
    if not img_path.is_file():
        print(f"FAIL: image not found: {img_path}")
        return 1

    from PIL import Image
    from preprocessing import preprocess_image
    import numpy as np

    pil = Image.open(img_path).convert("RGB")
    arr = preprocess_image(pil)
    if arr is None:
        print("FAIL: preprocessing failed")
        return 1

    pred = model.predict(np.expand_dims(arr, 0), verbose=0)
    probs = np.asarray(pred).squeeze()
    print(f"Image: {img_path.name}")
    print(f"P(synthetic)={float(probs[0])*100:.2f}%  P(authentic)={float(probs[1])*100:.2f}%")
    confidence = float(probs[int(np.argmax(probs))]) * 100.0
    print(f"Confidence (predicted class): {confidence:.2f}%")
    if confidence <= 0.01 and float(probs[0]) <= 0.01 and float(probs[1]) <= 0.01:
        print("WARN: all probabilities near zero — model output looks invalid.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
