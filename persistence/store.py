"""
Lightweight persistence of the ResonanceField.
Only the fixed-size state + minimal metadata is stored.
"""

from __future__ import annotations

import json
from pathlib import Path
import numpy as np
from core.field import ResonanceField


def save_field(field: ResonanceField, path: str | Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "dim": field.dim,
        "collapse_count": field.collapse_count,
        "magnitude_log": field.magnitude_log[-100:],
        "state": field.state.tolist(),
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def load_field(path: str | Path) -> ResonanceField | None:
    path = Path(path)
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    field = ResonanceField(dim=data["dim"])
    field.state = np.array(data["state"], dtype=np.float64)
    field.collapse_count = data.get("collapse_count", 0)
    field.magnitude_log = data.get("magnitude_log", [])
    return field
