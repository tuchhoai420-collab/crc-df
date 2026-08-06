"""
Stabilisation dynamics.

A query perturbs the field. We let the system settle for a fixed number of steps.
The final geometry is the answer.
"""

from __future__ import annotations

import numpy as np
from .field import ResonanceField
from .collapse import text_to_vector


def stabilise(field: ResonanceField, query: str, steps: int = 12, step_size: float = 0.08) -> np.ndarray:
    """
    Perturb the field with the query and run a short dynamical settling.
    Returns the settled state (copy).
    """
    q = text_to_vector(query, field.dim)
    q = field.project(q)

    s = field.state.copy()

    for _ in range(steps):
        attraction = q - np.dot(s, q) * s
        s += step_size * attraction
        s *= 0.995
        norm = np.linalg.norm(s)
        if norm > 1e-12:
            s /= norm

    return s


def decode_proximity(settled: np.ndarray, candidates: list[str], dim: int, top_k: int = 3) -> list[tuple[str, float]]:
    """
    Lightweight decoder: rank candidate strings by cosine similarity
    to the settled state. Useful for evaluation and demos.
    """
    scores = []
    for c in candidates:
        v = text_to_vector(c, dim)
        sim = float(np.dot(settled, v) / (np.linalg.norm(settled) * np.linalg.norm(v) + 1e-12))
        scores.append((c, sim))
    scores.sort(key=lambda x: x[1], reverse=True)
    return scores[:top_k]
