"""
Irreversible collapse operators.

A collapse permanently deforms the field.
There is no inverse operation.
"""

from __future__ import annotations

import numpy as np
from .field import ResonanceField


def text_to_vector(text: str, dim: int) -> np.ndarray:
    """Deterministic, cheap text → vector mapping (no external models)."""
    vec = np.zeros(dim, dtype=np.float64)
    text = text.lower().strip()
    if not text:
        return vec
    for i, ch in enumerate(text):
        h = hash(ch) % dim
        vec[h] += 1.0
        if i + 1 < len(text):
            bigram = text[i:i+2]
            h2 = hash(bigram) % dim
            vec[h2] += 0.6
    norm = np.linalg.norm(vec)
    if norm > 1e-12:
        vec /= norm
    return vec


def collapse(field: ResonanceField, observation: str, strength: float = 1.0) -> None:
    """
    Irreversibly deform the field with the observation.

    strength controls how strongly the new information warps the geometry.
    Typical range: 0.1 – 1.5
    """
    if strength <= 0:
        return

    obs_vec = text_to_vector(observation, field.dim)
    obs_vec = field.project(obs_vec)

    direction = obs_vec - np.dot(field.state, obs_vec) * field.state
    dir_norm = np.linalg.norm(direction)
    if dir_norm > 1e-9:
        direction /= dir_norm
        field.state += strength * 0.15 * direction
        field.state /= (np.linalg.norm(field.state) + 1e-12)

    field.collapse_count += 1
    field.magnitude_log.append(float(strength))
    if len(field.magnitude_log) > 500:
        field.magnitude_log = field.magnitude_log[-300:]
